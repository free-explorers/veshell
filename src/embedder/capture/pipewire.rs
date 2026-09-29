//! PipeWire screen-cast producer (capture specification section 7).
//!
//! One video producer stream per consented sharing session. The stream
//! negotiates one tested SDR packed format (RGBA, physical output size)
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
use std::collections::{HashMap, HashSet};
use std::io::Cursor;
use std::os::fd::{AsFd, BorrowedFd};
use std::ptr::NonNull;

use pipewire as pipewire_crate;
use pipewire::keys;
use pipewire::registry::GlobalObject;
use pipewire::spa::utils::dict::DictRef;
use pipewire::types::ObjectType;
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
use smithay::utils::{Logical, Physical, Point, Rectangle, Size};
use zbus::zvariant::OwnedObjectPath;

use crate::portal::service::SourceKind;
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
    /// The consumer of a stream was identified from the PipeWire graph:
    /// `node_id` is the producer node, `pid` the consuming process, and
    /// `app_id` the identity the consumer node reported about itself. Either
    /// of the two may be absent; the portal proxy reports the portal's pid but
    /// names the real app on the node (`node.name=brave`).
    ConsumerIdentified {
        node_id: u32,
        pid: Option<i32>,
        app_id: Option<String>,
    },
    /// A stream or the core failed; the loop closes the affected session.
    Fatal {
        session_handle: OwnedObjectPath,
        message: String,
    },
}

/// Resolves which process (and, when it names itself, which app) consumes a
/// producer stream, using the PipeWire registry.
///
/// The portal `app_id` is client-supplied and can be empty, so the recording
/// app is identified from the link the server creates between our producer
/// node and the consumer's node: link -> input node -> owning client -> client
/// process id. When the portal frontend proxies the stream, that pid is the
/// portal's, so the node's self-reported identity (`node.name`, application
/// name, portal app id) is captured too and used as a second hint. Every fact
/// is read from the global's properties, so no extra proxy has to be bound and
/// kept alive.
#[derive(Default)]
struct ConsumerResolver {
    /// Producer node ids we own; only links from these are resolved.
    producer_nodes: HashSet<u32>,
    /// Node id -> owning client id (`client.id`).
    node_clients: HashMap<u32, u32>,
    /// Node id -> process id when the node itself reports it.
    node_pids: HashMap<u32, i32>,
    /// Node id -> the app identity the node reports about itself
    /// (`pipewire.access.portal.app_id` / `application.name` / `node.name`).
    /// Chromium names its capture node after the browser (`node.name=brave`),
    /// so this survives the portal proxying the pid.
    node_app_hints: HashMap<u32, String>,
    /// Client id -> process id (`application.process.id`).
    client_pids: HashMap<u32, i32>,
    /// Link id -> (output node id, input node id).
    links: HashMap<u32, (u32, u32)>,
    /// Identity properties seen on each Node global, keyed by global id.
    /// Diagnostic only: shows whether a proxy carries an app id at all.
    node_identity: HashMap<u32, String>,
    /// Identity properties seen on each Client global, keyed by global id.
    client_identity: HashMap<u32, String>,
}

/// The app identity a Node global reports about itself, if any.
///
/// Ordered most specific first: the portal's app id, then the client's
/// application name, then the node name the client chose (Chromium uses the
/// browser name here), then the binary.
fn node_app_hint(props: &DictRef) -> Option<String> {
    for key in [
        "pipewire.access.portal.app_id",
        "application.name",
        "node.name",
        "application.process.binary",
    ] {
        if let Some(value) = props.get(key) {
            let value = value.trim();
            if !value.is_empty() {
                return Some(value.to_string());
            }
        }
    }
    None
}

/// The identity-bearing properties of a Node/Client global, formatted for logs.
fn identity_props(props: &DictRef) -> String {
    const KEYS: &[&str] = &[
        "application.name",
        "application.id",
        "application.process.binary",
        "application.process.id",
        "node.name",
        "node.description",
        "media.class",
        "pipewire.access.portal.app_id",
        "pipewire.access.portal.is_portal",
        "pipewire.access.portal.media_roles",
        "pipewire.sec.pid",
    ];
    let mut parts = Vec::new();
    for &key in KEYS {
        if let Some(value) = props.get(key) {
            parts.push(format!("{key}={value}"));
        }
    }
    parts.join(" ")
}

impl ConsumerResolver {
    /// Applies one registry global. Returns `true` when a table changed.
    fn apply_global(&mut self, global: &GlobalObject<&DictRef>) -> bool {
        match &global.type_ {
            ObjectType::Node => {
                let Some(props) = global.props else {
                    return false;
                };
                self.node_identity.insert(global.id, identity_props(props));
                if let Some(hint) = node_app_hint(props) {
                    self.node_app_hints.insert(global.id, hint);
                }
                let mut changed = false;
                if let Some(client) = props
                    .get(*keys::CLIENT_ID)
                    .and_then(|value| value.parse().ok())
                {
                    changed |= self.node_clients.insert(global.id, client) != Some(client);
                }
                if let Some(pid) = props
                    .get(*keys::APP_PROCESS_ID)
                    .and_then(|value| value.parse().ok())
                {
                    changed |= self.node_pids.insert(global.id, pid) != Some(pid);
                }
                changed
            }
            ObjectType::Client => {
                let Some(props) = global.props else {
                    return false;
                };
                self.client_identity
                    .insert(global.id, identity_props(props));
                // `application.process.id` is client-supplied; `pipewire.sec.pid`
                // is set by the protocol from the connecting socket. Prefer the
                // former and fall back to the latter, so a minimal client that
                // never sets the application key is still identified.
                let Some(pid) = props
                    .get(*keys::APP_PROCESS_ID)
                    .or_else(|| props.get(*keys::SEC_PID))
                    .and_then(|value| value.parse().ok())
                else {
                    return false;
                };
                self.client_pids.insert(global.id, pid) != Some(pid)
            }
            ObjectType::Link => {
                let Some(props) = global.props else {
                    return false;
                };
                let (Some(output), Some(input)) = (
                    props
                        .get(*keys::LINK_OUTPUT_NODE)
                        .and_then(|value| value.parse().ok()),
                    props
                        .get(*keys::LINK_INPUT_NODE)
                        .and_then(|value| value.parse().ok()),
                ) else {
                    return false;
                };
                self.links.insert(global.id, (output, input)) != Some((output, input))
            }
            _ => false,
        }
    }

    fn remove(&mut self, id: u32) {
        self.node_clients.remove(&id);
        self.node_pids.remove(&id);
        self.node_app_hints.remove(&id);
        self.client_pids.remove(&id);
        self.links.remove(&id);
        self.node_identity.remove(&id);
        self.client_identity.remove(&id);
    }

    /// Every consumer currently derivable from a link that feeds one of our
    /// nodes: `(producer node, pid, app hint)`. Either identity may be absent;
    /// a link with neither is dropped.
    fn resolved(&self) -> Vec<(u32, Option<i32>, Option<String>)> {
        self.links
            .values()
            .filter(|(output, _)| self.producer_nodes.contains(output))
            .filter_map(|(output, input)| {
                let pid = self.node_pids.get(input).copied().or_else(|| {
                    let client = self.node_clients.get(input)?;
                    self.client_pids.get(client).copied()
                });
                let app_id = self.node_app_hints.get(input).cloned();
                if pid.is_none() && app_id.is_none() {
                    return None;
                }
                Some((*output, pid, app_id))
            })
            .collect()
    }
}

/// What publishing a stream needs, resolved on the compositor loop at
/// approval time.
#[derive(Clone, Debug)]
pub struct StreamDescriptor {
    pub session_handle: OwnedObjectPath,
    /// PipeWire-consistent identity of the source (an output name or a
    /// MetaWindow id).
    pub source_id: String,
    /// The portal source kind the stream was approved for: it decides
    /// which rendering path fills the buffers.
    pub source_kind: SourceKind,
    /// Physical buffer size for the negotiated RGBA stream.
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
    /// The portal source kind of this stream (monitor or window).
    pub source_kind: SourceKind,
    pub position: (i32, i32),
    pub size: (i32, i32),
    pub label: String,
    /// The requesting application's id (portal `app_id`), used by the shell to
    /// put the recording indicator on the workspace that holds the app.
    pub app_id: String,
    /// The process consuming the stream, resolved from the PipeWire graph.
    /// Unlike `app_id` this is compositor-observed and drives the recording
    /// indicator.
    pub consumer_pid: Option<i32>,
    /// The app identity the consumer's PipeWire node reported about itself.
    /// The portal proxies the stream, so the consumer pid is the portal's; this
    /// is what still names the real app (Chromium sets `node.name=brave`).
    pub consumer_app_id: Option<String>,
    /// Whether a consumer is pulling frames right now.
    pub active: bool,
    /// Last frame copy for this stream: the 30 FPS budget is enforced
    /// against output-damage presents, never above.
    pub last_frame: Option<std::time::Instant>,
    /// Transient restore grant carried in the Start result (Chromium
    /// 105+ stream restoration): `Some(token)` means the backend granted
    /// `persist_mode = 1` for this approval.
    pub restore_token: Option<String>,
}

/// The PipeWire global: core plus the calloop integration.
pub struct Producer {
    _context: ContextRc,
    pub core: CoreRc,
    _integration: RegistrationToken,
    /// Keeps the pw main loop identity alive.
    _main_loop: MainLoopRc,
    /// Resolves a stream's consuming process from the PipeWire graph.
    resolver: Rc<RefCell<ConsumerResolver>>,
    /// Registry listener; must drop before `_registry` so it unregisters
    /// while the proxy is still alive.
    _registry_listener: pipewire::registry::Listener,
    _registry: pipewire::registry::RegistryRc,
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

/// One format offer: RGBA only, fixed size, framerate parameterized by
/// the output refresh, capped at the 30 FPS budget.
/// Retained the shell format offer shape; the stream today connects with
/// the negotiated params only (this backend's role).
#[allow(dead_code)]
fn make_video_params(buffer: &mut Vec<u8>, size: Size<i32, Physical>) -> &Pod {
    let object = pod::object!(
        SpaTypes::ObjectParamFormat,
        ParamType::EnumFormat,
        pod::property!(FormatProperties::MediaType, Id, MediaType::Video),
        pod::property!(FormatProperties::MediaSubtype, Id, MediaSubtype::Raw),
        // RGBA byte order matches the compositor readback exactly: the
        // M1 Abgr8888 framebuffer maps back as R,G,B,A bytes, and the
        // first real session streamed red/blue-swapped because a BGRx
        // declare was negotiated against those bytes.
        pod::property!(FormatProperties::VideoFormat, Id, VideoFormat::RGBA),
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

        // The registry maps the graph so the recording process can be named
        // from the link that feeds our stream (see [ConsumerResolver]).
        let registry = core
            .get_registry_rc()
            .map_err(|error| format!("Registry: {error:?}"))?;
        let resolver = Rc::new(RefCell::new(ConsumerResolver::default()));
        let resolver_global = resolver.clone();
        let resolver_remove = resolver.clone();
        let to_loop_registry = to_loop.clone();
        let registry_listener = registry
            .add_listener_local()
            .global(move |global| {
                let mut resolver = resolver_global.borrow_mut();
                let changed = resolver.apply_global(global);
                // Diagnostic for the screen-cast attribution: a link is the
                // only place the consuming process is named, so dump the graph
                // tables whenever one is seen.
                if matches!(global.type_, ObjectType::Link) {
                    if let Some((output, input)) = resolver.links.get(&global.id).copied() {
                        let input_client = resolver.node_clients.get(&input).copied();
                        tracing::debug!(
                            link_id = global.id,
                            producer = output,
                            input,
                            from_producer = resolver.producer_nodes.contains(&output),
                            node_identity = %resolver
                                .node_identity
                                .get(&input)
                                .map(String::as_str)
                                .unwrap_or(""),
                            client_identity = %input_client
                                .and_then(|client| resolver.client_identity.get(&client))
                                .map(String::as_str)
                                .unwrap_or(""),
                            client_pid = ?input_client
                                .and_then(|client| resolver.client_pids.get(&client)),
                            "pipewire link consumer identity"
                        );
                    }
                }
                if !changed {
                    return;
                }
                let resolved = resolver.resolved();
                if !resolved.is_empty() {
                    tracing::debug!(?resolved, "pipewire consumers resolved");
                }
                for (node_id, pid, app_id) in resolved {
                    let _ = to_loop_registry.send(ProducerEvent::ConsumerIdentified {
                        node_id,
                        pid,
                        app_id,
                    });
                }
            })
            .global_remove(move |id| resolver_remove.borrow_mut().remove(id))
            .register();

        Ok(Self {
            _context: context,
            _main_loop: main_loop,
            core,
            _integration: integration,
            resolver,
            _registry_listener: registry_listener,
            _registry: registry,
            to_loop,
            streams: HashMap::new(),
        })
    }

    /// Registers a producer stream node so links feeding it resolve to the
    /// consuming process. Also flushes any link that already exists.
    pub fn register_stream_node(&self, node_id: u32) {
        tracing::debug!(
            node_id,
            "producer stream node registered for consumer resolution"
        );
        let resolved = {
            let mut resolver = self.resolver.borrow_mut();
            resolver.producer_nodes.insert(node_id);
            resolver.resolved()
        };
        for (producer_node, pid, app_id) in resolved {
            let _ = self.to_loop.send(ProducerEvent::ConsumerIdentified {
                node_id: producer_node,
                pid,
                app_id,
            });
        }
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
        let to_loop_params = to_loop.clone();
        let lock = inner.clone();
        let lock_params = inner.clone();
        let lock_buffers = inner.clone();
        let lock_remove = inner.clone();

        let listener = stream
            .add_local_listener_with_user_data(())
            .state_changed(move |stream, (), _old, new| {
                let handle = lock.borrow().descriptor.session_handle.clone();
                match new {
                    // The proxy is not bound yet in Connecting: node_id
                    // is PW_ID_ANY, so publishing here would latch an
                    // invalid identity. Paused is the first state with a
                    // bound node, and it still precedes the consumer's
                    // fixate handshake (the daemon links the consumer
                    // after Start returns, which needs this id).
                    StreamState::Connecting => {
                        tracing::debug!("stream connecting");
                    }
                    StreamState::Paused => {
                        let mut inner = lock.borrow_mut();
                        if inner.node_id.is_some() {
                            return;
                        }
                        let node_id = stream.node_id();
                        if node_id == pipewire_crate::constants::ID_ANY {
                            tracing::warn!("stream paused without a bound node id");
                            return;
                        }
                        inner.node_id = Some(node_id);
                        if inner.ready_size.is_none() {
                            tracing::debug!(state = ?new, "stream connected; node published before the format fixated");
                        }
                        drop(inner);
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
                    // A stream that falls back to Unconnected after being
                    // linked has died; the session must close rather than
                    // keep a dead node. Intentional teardown drops the
                    // listener before the stream, so it never reaches here.
                    StreamState::Unconnected => {
                        let _ = to_loop_paused.send(ProducerEvent::Fatal {
                            session_handle: handle,
                            message: "stream disconnected".to_string(),
                        });
                    }
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
                // A stream that never fixates is silently frameless for
                // the whole session; before the format is ready, any
                // unusable negotiation closes the session instead.
                let fatal = |message: String| {
                    tracing::warn!("{message}");
                    if lock_params.borrow().ready_size.is_none() {
                        let session_handle = lock_params.borrow().descriptor.session_handle.clone();
                        let _ = to_loop_params.send(ProducerEvent::Fatal {
                            session_handle,
                            message,
                        });
                    }
                };
                if id != ParamType::Format.as_raw() {
                    return;
                }
                let Some(pod) = pod else { return };
                let Ok((m_type, m_subtype)) = parse_format(pod) else {
                    fatal("pipewire sent an unparsable format".to_string());
                    return;
                };
                if m_type != MediaType::Video || m_subtype != MediaSubtype::Raw {
                    fatal("pipewire negotiated a non-raw-video format".to_string());
                    return;
                }

                let negotiated_size = {
                    let mut format = VideoInfoRaw::new();
                    if format.parse(pod).is_err() {
                        fatal("error parsing the negotiated format".to_string());
                        return;
                    }
                    if format.format() != VideoFormat::RGBA {
                        fatal("pipewire negotiated away RGBA; stream unusable".to_string());
                        return;
                    }
                    Size::<i32, Physical>::from((
                        format.size().width as i32,
                        format.size().height as i32,
                    ))
                };

                let expected = lock_params.borrow().descriptor.size;
                if negotiated_size != expected {
                    fatal("negotiated size does not match the output size".to_string());
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
                if (*spa_buffer).n_datas < 1 || (*spa_buffer).datas.is_null() {
                    return;
                }
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
        // The frame geometry is fixed at negotiation: a size drift means
        // the output mode changed under the session, and a truncated or
        // short frame would reach the consumer as garbage. Close instead
        // of silently copying a partial frame.
        let expected_len = size.w as usize * size.h as usize * BYTES_PER_PIXEL;
        if pixels.len() != expected_len {
            let _ = self.to_loop.send(ProducerEvent::Fatal {
                session_handle,
                message: format!("frame is {} bytes, expected {expected_len}", pixels.len()),
            });
            return;
        }
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
