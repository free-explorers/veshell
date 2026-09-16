//! PipeWire screen-cast producer (capture specification section 7).
//!
//! One video producer stream per consented sharing session. The stream
//! negotiates one tested SDR packed format (BGRx, physical output size)
//! and producer-owned memfd shared-memory buffers. No consumer sees a
//! node before approval, and every published node contains only its own
//! source (per source, never a chooser preview or another session's
//! frame).
//!
//! The PipeWire main loop FD is integrated into the compositor calloop as
//! a level-triggered source and dispatched without blocking, following
//! Niri's pattern rather than carrying its entire module over. All
//! capture-per-frame work happens on the compositor loop; no PipeWire
//! real-time callback touches the renderer.

use std::cell::RefCell;
use std::collections::HashMap;
use std::io::Cursor;
use std::os::fd::{AsFd, BorrowedFd};
use std::ptr::NonNull;

use pipewire as pipewire_crate;
use pipewire_crate::sys as pipewire_sys;
use std::rc::Rc;

use pipewire::context::ContextRc;
use pipewire::core::{CoreRc, PW_ID_CORE};
use pipewire::loop_::Timeout;
use pipewire::main_loop::MainLoopRc;
use pipewire::properties::PropertiesBox;
use pipewire::spa::buffer::meta::MetaHeader;
use pipewire::spa::buffer::{meta::Metadata, DataFlags, DataType};
use pipewire::spa::param::format::{FormatProperties, MediaSubtype, MediaType};
use pipewire::spa::param::format_utils::parse_format;
use pipewire::spa::param::video::{VideoFormat, VideoInfoRaw};
use pipewire::spa::param::ParamType;
use pipewire::spa::pod::serialize::PodSerializer;
use pipewire::spa::pod::{self, ChoiceValue, Pod, Property};
use pipewire::spa::sys::{self, spa_meta_header};
use pipewire::spa::utils::{
    Choice, ChoiceEnum, ChoiceFlags, Direction, Fraction, Rectangle as SpaRectangle, SpaTypes,
};
use pipewire::stream::{Stream, StreamFlags, StreamListener, StreamRc, StreamState};
use pipewire::sys::{pw_buffer, pw_stream_queue_buffer, pw_stream_return_buffer};

use smithay::reexports::calloop::generic::Generic;
use smithay::reexports::calloop::{Interest, LoopHandle, Mode, PostAction, RegistrationToken};
use smithay::utils::{Logical, Physical, Size};
use zbus::zvariant::OwnedObjectPath;

use crate::state::State;
use crate::Backend;

/// Frame budget ceiling: never faster than 30 FPS regardless of consumer.
const MAX_FRAMERATE_NUM: u32 = 30;
const BYTES_PER_PIXEL: usize = 4;

/// Producer events delivered to the compositor loop from the PipeWire
/// main loop.
pub enum ProducerEvent {
    /// The node identity exists: Start completes now. The consumer needs
    /// the node id to connect; waiting for both sides to stream would
    /// deadlock startup (capture specification section 7: do not wait for
    /// a consuming application to stream).
    NodeReady {
        session_handle: OwnedObjectPath,
        node_id: u32,
    },
    /// The consumer connected or disconnected.
    ConsumerChanged {
        session_handle: OwnedObjectPath,
        active: bool,
    },
    /// A stream or the core failed; the loop closes the affected session.
    Fatal {
        session_handle: OwnedObjectPath,
        message: String,
    },
}

/// What publishing a stream needs, resolved on the compositor loop at
/// approval time.
#[derive(Clone, Debug)]
pub struct StreamDescriptor {
    pub session_handle: OwnedObjectPath,
    /// PipeWire-consistent identity of the source (an output name today).
    pub source_id: String,
    /// Physical buffer size for the negotiated BGRx stream.
    pub size: Size<i32, Physical>,
    /// Global logical position the portal Start result reports.
    pub position: (i32, i32),
    pub label: String,
}

/// Loop-side state of a live stream (what Start reports and the indicator
/// runs on).
#[derive(Clone, Debug)]
pub struct ActiveStream {
    pub node_id: u32,
    /// The source the stream was approved from; frame delivery matches
    /// fresh output damage against this id.
    pub source_id: String,
    pub position: (i32, i32),
    pub size: (i32, i32),
    pub label: String,
    /// Whether a consumer is pulling frames right now.
    pub active: bool,
    /// Last frame copy for this stream: the 30 FPS budget is enforced
    /// against output-damage presents, never above.
    pub last_frame: Option<std::time::Instant>,
}

/// The PipeWire global: core plus the calloop integration.
pub struct Producer {
    _context: ContextRc,
    pub core: CoreRc,
    _integration: RegistrationToken,
    /// Keeps the pw main loop identity alive.
    _main_loop: MainLoopRc,
    /// The compositor loop answers one [ProducerEvent] per pw call back.
    to_loop: smithay::reexports::calloop::channel::Sender<ProducerEvent>,
    streams: HashMap<OwnedObjectPath, StreamEntry>,
}

struct StreamEntry {
    // The listener must drop before the stream to avoid a use-after-free:
    // store it as an Option and take it on teardown. It starts as None
    // because the entry exists for a moment before `attach_listeners`
    // builds it: a zero placeholder is not valid here (StreamListener
    // holds a non-null inner pointer; zeroing it aborts the process).
    listener: Option<StreamListener<()>>,
    stream: StreamRc,
    inner: Rc<RefCell<StreamInner>>,
}

/// Mutable producer state shared with the PipeWire callbacks.
struct StreamInner {
    descriptor: StreamDescriptor,
    /// Negotiated buffer size; None until the SPA fixated the format.
    ready_size: Option<Size<i32, Physical>>,
    node_id: Option<u32>,
    /// Frames are written directly into the pw-negotiated MemFd buffers.
    /// With `MAP_BUFFERS`, `add_buffer` hands over an already-mapped
    /// `spa_data.data`; the compositor records it keyed by the buffer's
    /// mapped pointer so `queue_frame` can copy without touching fd
    /// bookkeeping.
    buffers: HashMap<*mut u8, usize>,
}

// Raw mapped pointers keyed across callback invocations; the memory is
// valid only while the buffer registration is in the map.
unsafe impl Send for StreamInner {}

fn make_pod(buffer: &mut Vec<u8>, object: pod::Object) -> &Pod {
    PodSerializer::serialize(Cursor::new(&mut *buffer), &pod::Value::Object(object))
        .expect("pod serialization is infallible in memory");
    Pod::from_bytes(buffer).expect("pod rehydration from owned memory")
}

/// One format offer: BGRx only, fixed size, framerate parameterized by
/// the output refresh, capped at the 30 FPS budget.
fn make_video_params(buffer: &mut Vec<u8>, size: Size<i32, Physical>) -> &Pod {
    let object = pod::object!(
        SpaTypes::ObjectParamFormat,
        ParamType::EnumFormat,
        pod::property!(FormatProperties::MediaType, Id, MediaType::Video),
        pod::property!(FormatProperties::MediaSubtype, Id, MediaSubtype::Raw),
        pod::property!(FormatProperties::VideoFormat, Id, VideoFormat::BGRx),
        pod::property!(
            FormatProperties::VideoSize,
            Rectangle,
            SpaRectangle {
                width: size.w as u32,
                height: size.h as u32,
            }
        ),
        pod::property!(
            FormatProperties::VideoFramerate,
            Fraction,
            Fraction { num: 0, denom: 1 }
        ),
        // Fixed framerate range [1, 30]: the consumer passes on a rate it
        // can keep up with, the producer never promises above 30 FPS.
        pod::property!(
            FormatProperties::VideoMaxFramerate,
            Choice,
            Range,
            Fraction,
            Fraction {
                num: MAX_FRAMERATE_NUM,
                denom: 1
            },
            Fraction { num: 1, denom: 1 },
            Fraction {
                num: MAX_FRAMERATE_NUM,
                denom: 1
            }
        ),
    );
    make_pod(buffer, object)
}

impl Producer {
    /// Connects to the user's session PipeWire daemon and registers the
    /// PipeWire main loop FD into calloop, dispatching without blocking.
    pub fn new<BackendData: Backend + 'static>(
        loop_handle: &LoopHandle<'static, State<BackendData>>,
        to_loop: smithay::reexports::calloop::channel::Sender<ProducerEvent>,
    ) -> Result<Self, String> {
        let main_loop = MainLoopRc::new(None).map_err(|error| format!("MainLoop: {error:?}"))?;
        let context =
            ContextRc::new(&main_loop, None).map_err(|error| format!("Context: {error:?}"))?;
        let core = context
            .connect_rc(None)
            .map_err(|error| format!("Core: {error:?}"))?;

        // Core-level errors reset the whole producer: every session
        // closes, every pending consent dies, and no old authorization
        // silently restores (capture specification sections 7, 8.3).
        let to_loop_ = to_loop.clone();
        let listener = core
            .add_listener_local()
            .error(move |id, seq, res, message| {
                tracing::warn!(id, seq, res, message, "pipewire core error");
                if id == PW_ID_CORE && res == -32 {
                    // The state sees PW_ID_CORE with all sessions dead:
                    // a sentinel path handles it (see the loop handler).
                    let handle = OwnedObjectPath::try_from("/org/freedesktop/portal/desktop")
                        .expect("backend object path is always valid");
                    let _ = to_loop_.send(ProducerEvent::Fatal {
                        session_handle: handle,
                        message: message.to_string(),
                    });
                }
            })
            .register();
        std::mem::forget(listener);

        struct AsFdWrapper(MainLoopRc);
        impl AsFd for AsFdWrapper {
            fn as_fd(&self) -> BorrowedFd<'_> {
                self.0.loop_().fd()
            }
        }
        let generic = Generic::new(AsFdWrapper(main_loop.clone()), Interest::READ, Mode::Level);
        let integration = loop_handle
            .insert_source(generic, move |_, wrapper, _| {
                wrapper.0.loop_().iterate(Timeout::None);
                Ok::<PostAction, std::io::Error>(PostAction::Continue)
            })
            .map_err(|error| format!("calloop integration: {error}"))?;

        Ok(Self {
            _context: context,
            _main_loop: main_loop,
            core,
            _integration: integration,
            to_loop,
            streams: HashMap::new(),
        })
    }

    /// Publishes the video stream for a consented session. No node exists
    /// before this call; the NodeReady event lands once the node identity
    /// is live. The stream belongs to the session's handle: every later
    /// PipeWire-level error closes that session exactly.
    pub fn start_stream(&mut self, descriptor: StreamDescriptor) {
        let session_handle = descriptor.session_handle.clone();
        // A session never owns two streams: two consents in one session
        // are rejected at consent time, and closing a session drops its
        // stream.
        if self.streams.contains_key(&session_handle) {
            tracing::warn!("stream already active for this session, ignoring");
            return;
        }

        // Consumers discover the producer through the standard
        // Video/Source media class, with the target label attached.
        let mut stream_props = PropertiesBox::new();
        stream_props.insert("media.class", "Video/Source");
        stream_props.insert("node.name", "veshell-screen-cast");
        stream_props.insert("node.description", descriptor.label.as_str());
        let Ok(stream) = StreamRc::new(self.core.clone(), "veshell-screen-cast-src", stream_props)
        else {
            let _ = self.to_loop.send(ProducerEvent::Fatal {
                session_handle,
                message: "PipeWire stream creation failed".to_string(),
            });
            return;
        };

        let inner = Rc::new(RefCell::new(StreamInner {
            descriptor: descriptor.clone(),
            ready_size: None,
            node_id: None,
            buffers: HashMap::new(),
        }));
        self.streams.insert(
            session_handle.clone(),
            StreamEntry {
                listener: None,
                stream: stream.clone(),
                inner: inner.clone(),
            },
        );

        self.attach_listeners(&session_handle, stream, inner, descriptor);
    }

    fn attach_listeners(
        &mut self,
        session_handle: &OwnedObjectPath,
        stream: StreamRc,
        inner: Rc<RefCell<StreamInner>>,
        descriptor: StreamDescriptor,
    ) {
        let to_loop = self.to_loop.clone();
        let to_loop_paused = to_loop.clone();
        let to_loop_streaming = to_loop.clone();
        let lock = inner.clone();
        let lock_params = inner.clone();
        let lock_buffers = inner.clone();
        let lock_remove = inner.clone();

        let listener = stream
            .add_local_listener_with_user_data(())
            .state_changed(move |stream, (), _old, new| {
                let handle = lock.borrow().descriptor.session_handle.clone();
                match new {
                    // The node identity exists as soon as the stream is
                    // accepted in the graph (mutter's ordering, proven by
                    // `no target node available` when any producer waits
                    // for a fixate no consumer can initiate). Start
                    // completes with the node id pre-fixate; the fixate
                    // itself happens when the daemon links the consumer's
                    // stream to this node (param_changed fires then).
                    StreamState::Connecting | StreamState::Paused => {
                        let mut inner = lock.borrow_mut();
                        if inner.ready_size.is_none() {
                            tracing::debug!(state = ?new, "stream connected; node published before the format fixated");
                        }
                        let node_id = *inner.node_id.get_or_insert_with(|| stream.node_id());
                        let _ = to_loop_paused.send(ProducerEvent::NodeReady {
                            session_handle: handle,
                            node_id,
                        });
                    }
                    StreamState::Error(error) => {
                        let _ = to_loop_paused.send(ProducerEvent::Fatal {
                            session_handle: handle,
                            message: format!("stream error: {error:?}"),
                        });
                    }
                    StreamState::Streaming => {
                        let _ = to_loop_streaming.send(ProducerEvent::ConsumerChanged {
                            session_handle: handle,
                            active: true,
                        });
                    }
                    StreamState::Unconnected => (),
                }
            })
            .param_changed(move |stream, (), id, pod| {
                // The fixate handshake: the daemon picks a format from the
                // params offered at connect; the producer answers with the
                // fixed buffer params once the SPA settles. Trace every
                // callback first: an unfixated stream is otherwise silent.
                tracing::debug!(
                    param_id = id,
                    pod_size = pod.map(|pod| pod.as_bytes().len()).unwrap_or(0),
                    "param_changed"
                );
                if id != ParamType::Format.as_raw() {
                    return;
                }
                let Some(pod) = pod else { return };
                let Ok((m_type, m_subtype)) = parse_format(pod) else {
                    return;
                };
                if m_type != MediaType::Video || m_subtype != MediaSubtype::Raw {
                    return;
                }

                let negotiated_size = {
                    let mut format = VideoInfoRaw::new();
                    if format.parse(pod).is_err() {
                        tracing::warn!("error parsing the negotiated format");
                        return;
                    }
                    if format.format() != VideoFormat::BGRx {
                        tracing::warn!("pipewire negotiated away BGRx; stream unusable");
                        return;
                    }
                    Size::<i32, Physical>::from((
                        format.size().width as i32,
                        format.size().height as i32,
                    ))
                };

                let expected = lock_params.borrow().descriptor.size;
                if negotiated_size != expected {
                    tracing::warn!("negotiated size does not match the output size");
                    return;
                }
                lock_params.borrow_mut().ready_size = Some(expected);

                let mut b1 = Vec::new();
                let mut b2 = Vec::new();
                // Buffers params declare the standard sysmem portal
                // shape: pw-allocated MemFd shared memory (the merged
                // datatype must intersect the consumer's demand — the
                // live negotiation trace showed MemPtr-only intersected
                // with a MemFd-only consumer as empty, i.e. `error alloc
                // buffers`), geometry explicit, count as a 2..16 range.
                let stride = expected.w as usize * BYTES_PER_PIXEL;
                let total = stride * expected.h as usize;
                let buffers_object = pod::object!(
                    SpaTypes::ObjectParamBuffers,
                    ParamType::Buffers,
                    Property::new(
                        sys::SPA_PARAM_BUFFERS_buffers,
                        pod::Value::Choice(ChoiceValue::Int(Choice(
                            ChoiceFlags::empty(),
                            ChoiceEnum::Range {
                                default: 8,
                                min: 2,
                                max: 16
                            }
                        ))),
                    ),
                    Property::new(sys::SPA_PARAM_BUFFERS_blocks, pod::Value::Int(1),),
                    Property::new(sys::SPA_PARAM_BUFFERS_size, pod::Value::Int(total as i32),),
                    Property::new(
                        sys::SPA_PARAM_BUFFERS_stride,
                        pod::Value::Int(stride as i32),
                    ),
                    Property::new(
                        sys::SPA_PARAM_BUFFERS_dataType,
                        pod::Value::Choice(ChoiceValue::Int(Choice(
                            ChoiceFlags::empty(),
                            ChoiceEnum::Flags {
                                default: 1 << DataType::MemFd.as_raw(),
                                flags: vec![
                                    1 << DataType::MemFd.as_raw(),
                                    1 << DataType::MemPtr.as_raw(),
                                ],
                            }
                        ))),
                    ),
                );
                let meta_object = pod::object!(
                    SpaTypes::ObjectParamMeta,
                    ParamType::Meta,
                    Property::new(
                        sys::SPA_PARAM_META_type,
                        pod::Value::Id(pipewire::spa::utils::Id(
                            <MetaHeader as Metadata>::META_TYPE
                        )),
                    ),
                    Property::new(
                        sys::SPA_PARAM_META_size,
                        pod::Value::Int(std::mem::size_of::<spa_meta_header>() as i32),
                    ),
                );
                let pod1 = make_pod(&mut b1, buffers_object);
                let pod2 = make_pod(&mut b2, meta_object);
                let params = unsafe { &mut [pod1, pod2] };
                if let Err(error) = stream.update_params(params) {
                    tracing::warn!("error updating stream params: {error:?}");
                }
            })
            .add_buffer(move |_, (), buffer| {
                // pw owns the buffer memory and, with MAP_BUFFERS,
                // hands add_buffer a fully mapped MemFd: record the
                // mapped pointer (with its fillable size) so queue_frame
                // can copy without touching fd bookkeeping. The spa_data
                // is left exactly as pw allocated it.
                unsafe {
                    let spa_buffer = (*buffer).buffer;
                    if (*spa_buffer).n_datas < 1 {
                        tracing::warn!("spa buffer has no data planes");
                        return;
                    }
                    let raw_datas = (*spa_buffer).datas;
                    let data = *raw_datas;
                    if data.data.is_null() {
                        tracing::warn!("spa buffer has no mapped memory");
                        return;
                    }
                    let mapped = data.data as *mut u8;
                    lock_buffers
                        .borrow_mut()
                        .buffers
                        .insert(mapped, data.maxsize as usize);
                }
            })
            .remove_buffer(move |_, (), buffer| unsafe {
                let spa_buffer = (*buffer).buffer;
                let mapped = (*(*spa_buffer).datas).data as *mut u8;
                lock_remove.borrow_mut().buffers.remove(&mapped);
            })
            .register()
            .map_err(|error| format!("attach stream listener: {error}"))
            .expect("stream listener is supported by the PipeWire contract");

        let entry = self
            .streams
            .get_mut(session_handle)
            .expect("stream entry was just inserted");
        entry.listener = Some(listener);

        let mut b = Vec::new();
        let pod = make_video_params(&mut b, descriptor.size);
        let mut pods: [&Pod; 1] = [pod];
        if let Err(error) = stream.connect(
            Direction::Output,
            None,
            // MAP_BUFFERS: pw allocates the MemFd buffer memory itself
            // (the consumer's demand in the merged negotiation) and maps
            // it into this process; ALLOC_BUFFERS here would instead
            // require the client-side NO_MEM allocation that failed
            // live. The driver role stays: the shell drives the graph.
            StreamFlags::DRIVER | StreamFlags::MAP_BUFFERS,
            &mut pods,
        ) {
            let _ = self.to_loop.send(ProducerEvent::Fatal {
                session_handle: session_handle.clone(),
                message: format!("stream connect: {error:?}"),
            });
            self.streams.remove(session_handle);
        }
    }

    /// Queues a rendered frame into the shared buffers of the session.
    pub fn queue_frame(&mut self, session_handle: OwnedObjectPath, pixels: &[u8]) {
        let Some(entry) = self.streams.get(&session_handle) else {
            return;
        };
        let inner = entry.inner.borrow_mut();
        let Some(size) = inner.ready_size else {
            // not ready: drop frame - pw never handed a buffer
            return;
        };
        drop(inner);
        let _ = size;
        // Dequeue the buffer the consumer handed back for refill.
        let pw_buffer_ptr = unsafe { entry.stream.dequeue_raw_buffer() };
        let Some(pw_buffer_ptr) = std::ptr::NonNull::new(pw_buffer_ptr) else {
            return;
        };
        let mut inner = entry.inner.borrow_mut();
        unsafe {
            let spa_buffer = (*pw_buffer_ptr.as_ptr()).buffer;
            let raw_datas = (*spa_buffer).datas;
            let data = *raw_datas;
            let mapped = data.data as *mut u8;
            let Some(&capacity) = inner.buffers.get(&mapped) else {
                drop(pw_buffer_ptr);
                pw_stream_return_buffer(entry.stream.as_raw_ptr(), pw_buffer_ptr.as_ptr());
                return;
            };
            // Pixels land at chunk offset 0; the pw-negotiated memory's
            // stride matches the frame stride exactly (the Buffers pod
            // declared the geometry), so the copy is stride-exact.
            let copied = pixels.len().min(capacity);
            std::ptr::copy_nonoverlapping(pixels.as_ptr(), mapped, copied);
            let chunk = (*raw_datas).chunk;
            (*chunk).offset = 0;
            (*chunk).stride = (inner.descriptor.size.w as usize * BYTES_PER_PIXEL) as i32;
            (*chunk).size = copied as u32;
        }
        drop(inner);
        unsafe {
            pw_stream_queue_buffer(entry.stream.as_raw_ptr(), pw_buffer_ptr.as_ptr());
        }
    }

    /// Stops and removes the stream of a session: no other source may
    /// survive the session closing.
    pub fn stop_stream(&mut self, session_handle: &OwnedObjectPath) {
        if let Some(mut entry) = self.streams.remove(session_handle) {
            drop(entry.listener.take());
            let _ = entry.stream.disconnect();
        }
    }
}
