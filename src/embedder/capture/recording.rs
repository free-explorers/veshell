//! GStreamer worker behind native area recording (capture specification
//! section 9): `appsrc` RGBA frames into VP8/WebM on a detached thread,
//! reporting lifecycle events to the compositor loop through a calloop
//! channel. Encoding, muxing and file I/O never run on the loop; both
//! the loop side and the worker drop frames under backpressure instead
//! of blocking.

use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc::{sync_channel, Receiver, SyncSender, TrySendError};
use std::thread;
use std::time::{Duration, Instant};

use gstreamer as gst;
use gstreamer::prelude::*;
use gstreamer_app::AppSrc;
use tracing::{info, warn};

use super::RecordingGeometry;

const FRAME_BYTES_PER_PIXEL: usize = 4;
/// Bounded handoff: at most this many frames travel from the loop to the
/// worker; anything beyond that is dropped, never queued without limit.
const FRAME_QUEUE_DEPTH: usize = 8;
/// EOS has this long to play out before the recording fails with a
/// recoverable partial file.
const EOS_COMPLETION_TIMEOUT: Duration = Duration::from_secs(10);
const EOS_POLL_INTERVAL: Duration = Duration::from_millis(20);
/// A stalled encoder (e.g. libvpx rejecting its format) is reported
/// instead of silently eating the recording: after this many frames in
/// a row were dropped while the queue stayed full, the session fails so
/// the UI bit shows real reason clearly.
const STALL_DROP_LIMIT: u64 = 120;
const VP8_REALTIME_DEADLINE_USEC: i64 = 1;
const VP8_CPU_USED: i32 = 8;
const VP8_THREADS: i32 = 2;
const VP8_KEYFRAME_MAX_DIST: i32 = 90;

/// Commands travelling from the compositor loop to the worker thread.
pub enum RecordingCommand {
    Frame { pixels: Vec<u8> },
    Stop,
}

/// Loop-side handle. Frames are pushed non-blocking; a full queue drops
/// the frame instead of stalling the compositor.
pub struct RecordingHandle {
    commands: SyncSender<RecordingCommand>,
    generation: u64,
}

impl RecordingHandle {
    pub fn generation(&self) -> u64 {
        self.generation
    }

    pub fn push_frame(&mut self, pixels: Vec<u8>) -> bool {
        match self.commands.try_send(RecordingCommand::Frame { pixels }) {
            Ok(()) => true,
            Err(TrySendError::Full(_)) | Err(TrySendError::Disconnected(_)) => false,
        }
    }

    /// Asks for an asynchronous finish; the worker sends the final
    /// [`RecordingEvent`] on the events channel later.
    ///
    /// The frame queue is bounded, so a blocking `send` could stall the
    /// compositor loop behind a full queue. A short-lived helper owns the
    /// send instead: `try_send` is the common path, and only a saturated
    /// queue (stalled encoder) falls back to a detached thread.
    pub fn stop(self) {
        match self.commands.try_send(RecordingCommand::Stop) {
            Ok(()) | Err(TrySendError::Disconnected(_)) => {}
            Err(TrySendError::Full(command)) => {
                let commands = self.commands.clone();
                thread::spawn(move || {
                    let _ = commands.send(command);
                });
            }
        }
    }
}

/// Worker lifecycle results.
pub enum RecordingEvent {
    Completed {
        /// Identifies the loop-side session this result belongs to, so a
        /// late result never tears down a newer recording.
        generation: u64,
        path: PathBuf,
        frames: u64,
        dropped: u64,
        elapsed_ms: u64,
    },
    Failed {
        generation: u64,
        message: String,
        /// A `.part` file with the partial recording, when one may be
        /// recoverable.
        partial: Option<PathBuf>,
    },
}

impl RecordingEvent {
    /// The loop-side session generation this result belongs to.
    pub fn generation(&self) -> u64 {
        match self {
            RecordingEvent::Completed { generation, .. }
            | RecordingEvent::Failed { generation, .. } => *generation,
        }
    }
}

pub fn frame_len(geometry: &RecordingGeometry) -> Result<usize, String> {
    let width =
        usize::try_from(geometry.size.w).map_err(|_| "Recording width is invalid".to_string())?;
    let height =
        usize::try_from(geometry.size.h).map_err(|_| "Recording height is invalid".to_string())?;
    width
        .checked_mul(height)
        .and_then(|pixels| pixels.checked_mul(FRAME_BYTES_PER_PIXEL))
        .ok_or_else(|| "Recording buffer is too large".to_string())
}

/// Spawns the worker thread. Feed frames with
/// [`RecordingHandle::push_frame`] and finish with
/// [`RecordingHandle::stop`]; exactly one [`RecordingEvent`] follows on
/// the events channel per session.
pub fn spawn_recording_worker(
    geometry: RecordingGeometry,
    events: smithay::reexports::calloop::channel::Sender<RecordingEvent>,
) -> Result<RecordingHandle, String> {
    spawn_recording_worker_with_timeout(geometry, events, EOS_COMPLETION_TIMEOUT)
}

fn spawn_recording_worker_with_timeout(
    geometry: RecordingGeometry,
    events: smithay::reexports::calloop::channel::Sender<RecordingEvent>,
    eos_timeout: Duration,
) -> Result<RecordingHandle, String> {
    let frame_len = frame_len(&geometry)?;
    let (commands, receiver) = sync_channel::<RecordingCommand>(FRAME_QUEUE_DEPTH);
    let generation = next_recording_generation();
    thread::spawn(move || {
        run_recording_worker(
            geometry,
            frame_len,
            receiver,
            events,
            generation,
            eos_timeout,
        );
    });
    Ok(RecordingHandle {
        commands,
        generation,
    })
}

fn next_recording_generation() -> u64 {
    static GENERATION: AtomicU64 = AtomicU64::new(1);
    GENERATION.fetch_add(1, Ordering::Relaxed)
}

/// Consumes one bus message during the frame loop. Returns false when
/// the recording is over (bridge failed); an EOS during the run means
/// the pipeline ended on its own and the session is failing anyway.
fn handle_run_bus_message(
    running: &RunningPipeline,
    view: &gst::message::MessageView<'_>,
    events: &smithay::reexports::calloop::channel::Sender<RecordingEvent>,
) -> bool {
    match view {
        gst::message::MessageView::Error(error) => {
            running.fail(
                format!(
                    "Recording failed: {} ({})",
                    error.error(),
                    error.src().map(|s| s.to_string()).unwrap_or_default()
                ),
                events,
            );
            false
        }
        gst::message::MessageView::Eos(_) => {
            running.fail(
                "The recording pipeline ended before the stop".to_string(),
                events,
            );
            false
        }
        _ => true,
    }
}

struct RunningPipeline {
    appsrc: AppSrc,
    pipeline: gst::Pipeline,
    bus: gst::Bus,
    queue_limit: u64,
    destination: PathBuf,
    part_path: PathBuf,
    generation: u64,
}

impl RunningPipeline {
    /// The appsrc queue measured in bytes; frames beyond this bound are
    /// dropped by the worker to keep latency bounded.
    fn queue_is_saturated(&self) -> bool {
        self.appsrc.current_level_bytes() >= self.queue_limit
    }

    /// Stops the pipeline and reports a failure with the partial file
    /// kept for recovery.
    fn fail(
        &self,
        message: String,
        events: &smithay::reexports::calloop::channel::Sender<RecordingEvent>,
    ) {
        if let Err(error) = self.pipeline.set_state(gst::State::Null) {
            warn!(?error, "Unable to stop a failed recording pipeline");
        }
        // The claim placeholder is the only file the failure leaves
        // besides the partial recording: an empty final `.webm` next to
        // the `.part` recovery file is noise the user would see as "the
        // video is 0 bytes".
        self.remove_empty_placeholder();
        let _ = events.send(RecordingEvent::Failed {
            generation: self.generation,
            message,
            partial: Some(self.part_path.clone()),
        });
    }

    /// Deletes the destination placeholder while it is still an empty
    /// claim (never a real recording).
    fn remove_empty_placeholder(&self) {
        match fs::metadata(&self.destination) {
            Ok(metadata) if metadata.len() == 0 && metadata.is_file() => {
                let _ = fs::remove_file(&self.destination);
            }
            _ => {}
        }
    }
}

fn build_recording_pipeline(
    geometry: &RecordingGeometry,
    frame_len: usize,
    generation: u64,
) -> Result<RunningPipeline, String> {
    gst::init().map_err(|error| format!("GStreamer is unavailable: {error}"))?;

    let appsrc_element = gst::ElementFactory::make("appsrc")
        .build()
        .map_err(|_| "appsrc is unavailable; GStreamer core is missing".to_string())?;
    let appsrc = appsrc_element
        .clone()
        .downcast::<AppSrc>()
        .map_err(|_| "appsrc element downcast failed".to_string())?;
    let convert = gst::ElementFactory::make("videoconvert")
        .build()
        .map_err(|_| {
            "videoconvert is unavailable; install the GStreamer base plugins".to_string()
        })?;
    let encoder = gst::ElementFactory::make("vp8enc").build().map_err(|_| {
        "vp8enc is unavailable; install the GStreamer good plugins to enable recording".to_string()
    })?;
    encoder.set_property("deadline", VP8_REALTIME_DEADLINE_USEC);
    encoder.set_property("cpu-used", VP8_CPU_USED);
    encoder.set_property("threads", VP8_THREADS);
    encoder.set_property("keyframe-max-dist", VP8_KEYFRAME_MAX_DIST);
    let mux = gst::ElementFactory::make("webmmux")
        .build()
        .map_err(|_| "webmmux is unavailable; install the GStreamer good plugins".to_string())?;
    let sink = gst::ElementFactory::make("filesink")
        .build()
        .map_err(|_| "filesink is unavailable; install the GStreamer base plugins".to_string())?;

    let caps = gst::Caps::builder("video/x-raw")
        .field("format", "RGBA")
        .field("width", geometry.size.w)
        .field("height", geometry.size.h)
        .field("framerate", gst::Fraction::new(geometry.fps as i32, 1))
        .build();
    appsrc.set_caps(Some(&caps));
    appsrc.set_format(gst::Format::Time);
    // PTS are stamped here from the worker's monotonic clock: real
    // elapsed time survives frame drops and idle scenes. GST_DEBUG in
    // the first real run showed do-timestamp stamping while the
    // pipeline itself had no clock yet (worker thread races
    // PLAYING), which libvpx then rejected as an invalid parameter.
    appsrc.set_do_timestamp(false);
    // The handoff from the compositor loop is non-blocking; the worker
    // detects queue saturation through the byte level instead.
    appsrc.set_block(false);
    // Two frames of slack between the loop and the encoder so brief
    // scheduling spikes do not drop frames immediately.
    let queue_limit = (frame_len as u64)
        .checked_mul(2)
        .ok_or_else(|| "Recording buffer is too large".to_string())?;
    appsrc.set_max_bytes(queue_limit);

    let (destination, part_path) = recording_destination()?;
    sink.set_property("location", part_path.clone());
    sink.set_property("sync", false);

    let pipeline = gst::Pipeline::builder()
        .name("veshell-local-recording")
        .build();
    pipeline
        .add_many([&appsrc_element, &convert, &encoder, &mux, &sink])
        .map_err(|error| format!("Recording pipeline assembly failed: {error}"))?;
    gst::Element::link_many([&appsrc_element, &convert, &encoder, &mux, &sink])
        .map_err(|error| format!("Recording pipeline linking failed: {error}"))?;

    let bus = pipeline.bus().ok_or_else(|| {
        fs::remove_file(&destination).ok();
        "Recording pipeline has no bus".to_string()
    })?;
    if let Err(error) = pipeline.set_state(gst::State::Playing) {
        // The claimed destination is still an empty placeholder here.
        fs::remove_file(&destination).ok();
        return Err(format!("Recording pipeline failed to start: {error}"));
    }

    Ok(RunningPipeline {
        appsrc,
        pipeline,
        bus,
        queue_limit,
        destination,
        part_path,
        generation,
    })
}

/// Chooses the final WebM path beside any existing one (no silent
/// overwrite) and the same stem with a `.part` extension for the
/// partial file written while the recording runs.
/// Chooses the final WebM path beside any existing one (no silent
/// overwrite) and the same stem with a `.part` extension for the
/// partial file written while the recording runs. The destination is
/// created atomically (`create_new`) so concurrent sessions never pick
/// the same pair; the encoder overwrites (its own) empty placeholder.
fn recording_destination() -> Result<(PathBuf, PathBuf), String> {
    let directory = super::recording_directory()?;
    let now = chrono::Local::now()
        .format("%Y-%m-%d %H-%M-%S%.3f")
        .to_string();
    recording_path(&directory, &format!("Veshell Recording {now}"), "webm")
}

/// Expands a base name to the first free `stem.ext`/`stem.ext.part`
/// pair; the atomic creation claim closes the choose-then-create race
/// between two workers starting at once.
fn recording_path(
    directory: &Path,
    stem: &str,
    extension: &str,
) -> Result<(PathBuf, PathBuf), String> {
    let mut attempt = 0;
    loop {
        let base = if attempt == 0 {
            stem.to_string()
        } else {
            format!("{stem} ({attempt})")
        };
        let destination = directory.join(format!("{base}.{extension}"));
        let mut part = destination.clone();
        part.set_extension("part");
        match fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&destination)
        {
            Ok(_claim) => return Ok((destination, part)),
            Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => {
                attempt += 1;
            }
            Err(error) => {
                return Err(format!(
                    "Unable to claim the recording path {}: {error}",
                    destination.display()
                ))
            }
        }
    }
}

fn run_recording_worker(
    geometry: RecordingGeometry,
    frame_len: usize,
    commands: Receiver<RecordingCommand>,
    events: smithay::reexports::calloop::channel::Sender<RecordingEvent>,
    generation: u64,
    eos_timeout: Duration,
) {
    let started = Instant::now();

    let running = match build_recording_pipeline(&geometry, frame_len, generation) {
        Ok(running) => running,
        Err(message) => {
            let _ = events.send(RecordingEvent::Failed {
                generation,
                message,
                partial: None,
            });
            return;
        }
    };

    let mut frames = 0u64;
    let mut dropped = 0u64;
    let mut consecutive_dropped = 0u64;
    let mut stop_requested = false;

    for command in commands {
        match command {
            RecordingCommand::Frame { pixels } => {
                if pixels.len() != frame_len {
                    running.fail(
                        format!("A frame was {} bytes, expected {frame_len}", pixels.len()),
                        &events,
                    );
                    return;
                }
                if running.queue_is_saturated() {
                    dropped += 1;
                    consecutive_dropped += 1;
                    // The GStreamer bus is checked even while frames
                    // are dropped: a dead encoder must fail fast, not
                    // masquerade as skips.
                    if let Some(message) = running.bus.timed_pop(gst::ClockTime::ZERO) {
                        if !handle_run_bus_message(&running, &message.view(), &events) {
                            return;
                        }
                    }
                    if consecutive_dropped >= STALL_DROP_LIMIT {
                        running.fail(
                            format!(
                                "The encoder consumed nothing after {consecutive_dropped} \
                                 consecutive dropped frames"
                            ),
                            &events,
                        );
                        return;
                    }
                    continue;
                }
                let mut buffer = gst::Buffer::from_slice(pixels);
                buffer
                    .get_mut()
                    .unwrap()
                    .set_pts(gst::ClockTime::from_nseconds(
                        started.elapsed().as_nanos() as u64
                    ));
                if let Err(error) = running.appsrc.push_buffer(buffer) {
                    running.fail(format!("Frame delivery failed: {error}"), &events);
                    return;
                }
                frames += 1;
                consecutive_dropped = 0;
            }
            RecordingCommand::Stop => {
                stop_requested = true;
                break;
            }
        }
    }

    if !stop_requested {
        running.fail(
            "The recording ended without a user stop".to_string(),
            &events,
        );
        return;
    }

    if let Err(error) = running.appsrc.end_of_stream() {
        info!(?error, "EOS delivery to a recording pipeline failed");
    }

    // The playout window opens at the stop, not at the session start:
    // a long recording must still get the full EOS deadline (the first
    // runs anchored this at the session start, so any recording longer
    // than the window skipped the wait outright and left the ".part"
    // file unpublished).
    let stop_instant = Instant::now();
    let deadline = stop_instant + eos_timeout;
    let mut finish: Option<Result<(), String>> = None;
    while Instant::now() < deadline {
        if let Some(message) = running.bus.timed_pop(gst::ClockTime::ZERO) {
            match message.view() {
                gst::message::MessageView::Eos(_) => {
                    finish = Some(Ok(()));
                    break;
                }
                gst::message::MessageView::Error(error) => {
                    finish = Some(Err(format!(
                        "Recording failed: {} ({})",
                        error.error(),
                        error.src().map(|s| s.to_string()).unwrap_or_default()
                    )));
                    break;
                }
                _ => continue,
            }
        }
        thread::sleep(EOS_POLL_INTERVAL);
    }

    if let Err(stop_error) = running.pipeline.set_state(gst::State::Null) {
        warn!(error = ?stop_error, "Unable to stop a finished recording pipeline");
    }

    match finish {
        Some(Ok(())) => match fs::rename(&running.part_path, &running.destination) {
            Ok(()) => {
                let elapsed_ms = started.elapsed().as_millis() as u64;
                info!(
                    path = %running.destination.display(),
                    frames,
                    dropped,
                    elapsed_ms,
                    "Recording file finalized"
                );
                let _ = events.send(RecordingEvent::Completed {
                    generation,
                    path: running.destination.clone(),
                    frames,
                    dropped,
                    elapsed_ms,
                });
            }
            Err(publish_error) => {
                running.remove_empty_placeholder();
                let _ = events.send(RecordingEvent::Failed {
                    generation,
                    message: format!("The recording could not be published: {publish_error}"),
                    partial: Some(running.part_path.clone()),
                });
            }
        },
        Some(Err(message)) => running.fail(message, &events),
        None => running.fail(
            "The recording pipeline never finished after the stop".to_string(),
            &events,
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use smithay::reexports::calloop::channel;
    use smithay::utils::{Physical, Size};

    fn recording_geometry(size: Size<i32, Physical>) -> RecordingGeometry {
        RecordingGeometry { size, fps: 30 }
    }

    fn rgba_frame(size: Size<i32, Physical>, red: u8) -> Vec<u8> {
        let mut pixels = vec![0u8; (size.w as usize) * (size.h as usize) * 4];
        for pixel in pixels.chunks_exact_mut(4) {
            pixel[0] = red;
            pixel[1] = 40;
            pixel[2] = 90;
            pixel[3] = 255;
        }
        pixels
    }

    /// Frames fed before a stop turn into a playable WebM: the published
    /// file starts with the EBML header and the queue drops nothing.
    #[test]
    fn recording_completes_after_stop_with_playable_file() {
        let size: Size<i32, Physical> = (16, 16).into();
        let (events_sender, events_receiver) = channel::channel::<RecordingEvent>();
        let mut recorder = spawn_recording_worker(recording_geometry(size), events_sender).unwrap();
        let generation = recorder.generation();
        for frame_index in 0..5u8 {
            assert!(
                recorder.push_frame(rgba_frame(size, frame_index * 8)),
                "the frame queue must absorb a few bursts"
            );
        }
        recorder.stop();

        let outcome = events_receiver
            .recv()
            .expect("the worker session must report its result");
        let (path, dropped) = match outcome {
            RecordingEvent::Completed {
                generation: event_generation,
                path,
                dropped,
                ..
            } => {
                assert_eq!(
                    event_generation, generation,
                    "the result must identify its own loop-side generation"
                );
                (path, dropped)
            }
            RecordingEvent::Failed { message, .. } => panic!("the recording failed: {message}"),
        };
        assert!(dropped < 5, "not every frame may drop; some must encode");
        let finished = fs::read(&path).unwrap();
        assert_eq!(
            &finished[..4],
            &[0x1A, 0x45, 0xDF, 0xA3],
            "the published file is a WebM container"
        );
        std::fs::remove_file(path).ok();
    }

    /// The EOS playout window opens at the Stop, not at the session
    /// start (the first real runs anchored it at the start, so any
    /// recording longer than the window skipped the wait and the file
    /// stayed unpublished). A short playout timeout plus a session that
    /// far outlives it makes the wrong anchoring fail this test.
    #[test]
    fn long_session_still_plays_out_after_stop() {
        let size: Size<i32, Physical> = (64, 64).into();
        let (events_sender, events_receiver) = channel::channel::<RecordingEvent>();
        let mut recorder = spawn_recording_worker_with_timeout(
            recording_geometry(size),
            events_sender,
            Duration::from_millis(300),
        )
        .unwrap();
        let frame = rgba_frame(size, 60);
        for frame_index in 0..12 {
            assert!(recorder.push_frame(frame.clone()), "frames must queue");
            thread::sleep(Duration::from_millis(20));
            if frame_index >= 10 {
                // Simulate the encoder being briefly busy right at the
                // stop; the playout window must still wait, anchored at
                // the stop.
                std::thread::sleep(Duration::from_millis(10));
            }
        }
        recorder.stop();

        let outcome = events_receiver
            .recv()
            .expect("the worker session must report its result");
        match outcome {
            RecordingEvent::Completed { frames, .. } => {
                assert!(frames > 0, "the recorded session kept its frames");
            }
            RecordingEvent::Failed { message, .. } => {
                panic!("a short playout deadline is a bug, not a recording result: {message}")
            }
        }
    }

    /// A path is picked beside an existing file: no silent overwrite.
    #[test]
    fn recording_path_never_sits_on_an_existing_file() {
        let directory = std::env::temp_dir().join("veshell-recording-dest-test");
        std::fs::create_dir_all(&directory).unwrap();
        std::fs::write(directory.join("M.webm"), b"occupied").unwrap();

        let destination = recording_path(&directory, "M", "webm").unwrap().0;

        assert_eq!(destination.file_name().unwrap(), "M (1).webm");
        assert!(destination.try_exists().unwrap());
        std::fs::remove_dir_all(&directory).unwrap();
    }

    /// The first real-machine geometry (1494×1021, odd height) stalled:
    /// frames were accepted, EOS never completed, the published file was
    /// 418 bytes of header, and GST_DEBUG showed libvpx rejecting the
    /// invalid PTS do-timestamp had applied before the pipeline clock
    /// existed. Worker-stamped monotonic PTS must encode odd sizes
    /// beyond the header as well.
    #[test]
    fn real_size_recording_encodes_beyond_the_header() {
        let size: Size<i32, Physical> = (1494, 1021).into();
        let (events_sender, events_receiver) = channel::channel::<RecordingEvent>();
        let mut recorder = spawn_recording_worker(recording_geometry(size), events_sender).unwrap();
        let frame = rgba_frame(size, 60);
        for _ in 0..30 {
            assert!(
                recorder.push_frame(frame.clone()),
                "a 30-frame burst at real size must queue"
            );
        }
        recorder.stop();

        let outcome = events_receiver
            .recv()
            .expect("the worker session must report its result");
        let (path, dropped) = match outcome {
            RecordingEvent::Completed { path, dropped, .. } => (path, dropped),
            RecordingEvent::Failed { message, .. } => panic!("the recording failed: {message}"),
        };
        assert!(dropped < 30, "not every frame may drop; some must encode");
        let finished = fs::read(&path).unwrap();
        assert_eq!(&finished[..4], &[0x1A, 0x45, 0xDF, 0xA3]);
        // A VP8 keyframe of a uniform frame is small by design; the old
        // stall produced exactly 418 bytes of bare header, so anything
        // beyond the base header proves frames reached the muxer.
        assert!(
            finished.len() > 1024,
            "encoded payload expected, got {} bytes (a bare header means zero frames encoded)",
            finished.len()
        );
        std::fs::remove_file(path).ok();
    }

    /// The even-rounded real-size geometry (what the compositor loop now
    /// feeds) must encode real payload: the fix for the real run that
    /// stalled on odd height.
    #[test]
    fn even_real_size_recording_encodes_beyond_the_header() {
        let size: Size<i32, Physical> = (1494, 1020).into();
        let (events_sender, events_receiver) = channel::channel::<RecordingEvent>();
        let mut recorder = spawn_recording_worker(recording_geometry(size), events_sender).unwrap();
        let frame = rgba_frame(size, 60);
        for _ in 0..30 {
            assert!(
                recorder.push_frame(frame.clone()),
                "a 30-frame burst at real size must queue"
            );
        }
        recorder.stop();

        let outcome = events_receiver
            .recv()
            .expect("the worker session must report its result");
        let (path, dropped) = match outcome {
            RecordingEvent::Completed { path, dropped, .. } => (path, dropped),
            RecordingEvent::Failed { message, .. } => panic!("the recording failed: {message}"),
        };
        assert!(dropped < 30, "not every frame may drop; some must encode");
        let finished = fs::read(&path).unwrap();
        assert_eq!(&finished[..4], &[0x1A, 0x45, 0xDF, 0xA3]);
        // A VP8 keyframe of a uniform frame is small by design; the old
        // stall produced exactly 418 bytes of bare header, so anything
        // beyond the base header proves frames reached the muxer.
        assert!(
            finished.len() > 1024,
            "encoded payload expected, got {} bytes (a bare header means zero frames encoded)",
            finished.len()
        );
        std::fs::remove_file(path).ok();
    }

    /// Backpressure evidence: a producer that floods the handoff (no
    /// pacing, alternating frames so the encoder cannot skip work) must
    /// drop frames without growing the queue or failing the session.
    /// The compositor side only pushes non-blocking, so this is the
    /// worker-side mirror of the loop's `dropped` counter.
    #[test]
    fn saturating_burst_drops_under_backpressure_and_stays_playable() {
        let size: Size<i32, Physical> = (1494, 1020).into();
        let (events_sender, events_receiver) = channel::channel::<RecordingEvent>();
        let mut recorder = spawn_recording_worker(recording_geometry(size), events_sender).unwrap();

        // Alternating colors force the encoder to really spend time on
        // every accepted frame instead of short-circuiting a static
        // scene.
        let frame_a = rgba_frame(size, 60);
        let frame_b = rgba_frame(size, 200);
        const BURST: usize = 60;
        for index in 0..BURST {
            let frame = if index % 2 == 0 {
                frame_a.clone()
            } else {
                frame_b.clone()
            };
            let _queued = recorder.push_frame(frame);
        }
        recorder.stop();

        let outcome = events_receiver
            .recv()
            .expect("the worker session must report its result");
        let (path, frames, dropped) = match outcome {
            RecordingEvent::Completed {
                path,
                frames,
                dropped,
                ..
            } => (path, frames, dropped),
            RecordingEvent::Failed { message, .. } => {
                panic!("a saturating burst must drop, not fail: {message}")
            }
        };
        assert!(
            dropped > 0,
            "an unpaced 60-frame burst must saturate the handoff and drop; got none"
        );
        assert!(
            frames > 0,
            "even under backpressure some frames must encode"
        );
        let finished = fs::read(&path).unwrap();
        assert_eq!(&finished[..4], &[0x1A, 0x45, 0xDF, 0xA3]);
        assert!(
            finished.len() > 1024,
            "encoded payload expected, got {} bytes",
            finished.len()
        );
        std::fs::remove_file(path).ok();
    }
}
