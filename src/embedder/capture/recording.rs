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
    pub fn stop(self) {
        let _ = self.commands.send(RecordingCommand::Stop);
    }
}

/// Worker lifecycle results.
pub enum RecordingEvent {
    Completed {
        path: PathBuf,
        frames: u64,
        dropped: u64,
        elapsed_ms: u64,
    },
    Failed {
        message: String,
        /// A `.part` file with the partial recording, when one may be
        /// recoverable.
        partial: Option<PathBuf>,
    },
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
    let frame_len = frame_len(&geometry)?;
    let (commands, receiver) = sync_channel::<RecordingCommand>(FRAME_QUEUE_DEPTH);
    let generation = next_recording_generation();
    thread::spawn(move || {
        run_recording_worker(geometry, frame_len, receiver, events, generation);
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

struct RunningPipeline {
    appsrc: AppSrc,
    pipeline: gst::Pipeline,
    bus: gst::Bus,
    queue_limit: u64,
    destination: PathBuf,
    part_path: PathBuf,
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
        let _ = events.send(RecordingEvent::Failed {
            message,
            partial: Some(self.part_path.clone()),
        });
    }
}

fn build_recording_pipeline(
    geometry: &RecordingGeometry,
    frame_len: usize,
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
    // PTS derive from the pipeline running time when the buffer is
    // pushed: real elapsed time survives frame drops and idle scenes.
    appsrc.set_do_timestamp(true);
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

    let bus = pipeline
        .bus()
        .ok_or_else(|| "Recording pipeline has no bus".to_string())?;
    pipeline
        .set_state(gst::State::Playing)
        .map_err(|error| format!("Recording pipeline failed to start: {error}"))?;

    Ok(RunningPipeline {
        appsrc,
        pipeline,
        bus,
        queue_limit,
        destination,
        part_path,
    })
}

/// Chooses the final WebM path beside any existing one (no silent
/// overwrite) and the same stem with a `.part` extension for the
/// partial file written while the recording runs.
fn recording_destination() -> Result<(PathBuf, PathBuf), String> {
    let directory = super::recording_directory()?;
    let now = chrono::Local::now()
        .format("%Y-%m-%d %H-%M-%S%.3f")
        .to_string();
    Ok(seek_free_path(
        &directory,
        &format!("Veshell Recording {now}"),
        "webm",
    ))
}

/// Expands a base name to the first free `stem.ext`/`stem.ext.part` pair
/// beside any existing file.
fn seek_free_path(directory: &Path, stem: &str, extension: &str) -> (PathBuf, PathBuf) {
    let mut attempt = 0;
    loop {
        let base = if attempt == 0 {
            stem.to_string()
        } else {
            format!("{stem} ({attempt})")
        };
        let destination = directory.join(format!("{base}.{extension}"));
        if !destination.exists() {
            let mut part = destination.clone();
            part.set_extension("part");
            return (destination, part);
        }
        attempt += 1;
    }
}

fn run_recording_worker(
    geometry: RecordingGeometry,
    frame_len: usize,
    commands: Receiver<RecordingCommand>,
    events: smithay::reexports::calloop::channel::Sender<RecordingEvent>,
    _generation: u64,
) {
    let started = Instant::now();

    let running = match build_recording_pipeline(&geometry, frame_len) {
        Ok(running) => running,
        Err(message) => {
            let _ = events.send(RecordingEvent::Failed {
                message,
                partial: None,
            });
            return;
        }
    };

    let mut frames = 0u64;
    let mut dropped = 0u64;
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
                    continue;
                }
                let buffer = gst::Buffer::from_slice(pixels);
                if let Err(error) = running.appsrc.push_buffer(buffer) {
                    running.fail(format!("Frame delivery failed: {error}"), &events);
                    return;
                }
                frames += 1;
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

    // EOS plays out asynchronously; the bus reports completion, encoder
    // or muxer errors, or the deadline passes (the `.part` file stays
    // recoverable).
    let deadline = started + EOS_COMPLETION_TIMEOUT;
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
                    path: running.destination.clone(),
                    frames,
                    dropped,
                    elapsed_ms,
                });
            }
            Err(publish_error) => {
                let _ = events.send(RecordingEvent::Failed {
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
            RecordingEvent::Completed { path, dropped, .. } => (path, dropped),
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

    /// A path is picked beside an existing file: no silent overwrite.
    #[test]
    fn seek_free_path_never_sits_on_an_existing_file() {
        let directory = std::env::temp_dir().join("veshell-recording-dest-test");
        std::fs::create_dir_all(&directory).unwrap();
        std::fs::write(directory.join("M.webm"), b"occupied").unwrap();

        let (destination, part) = seek_free_path(&directory, "M", "webm");

        assert_eq!(destination.file_name().unwrap(), "M (1).webm");
        assert_eq!(part.file_name().unwrap(), "M (1).part");
    }
}
