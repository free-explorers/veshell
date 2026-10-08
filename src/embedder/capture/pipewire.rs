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
use std::os::fd::{AsFd, AsRawFd, BorrowedFd, OwnedFd};
use std::ptr::NonNull;

use pipewire as pipewire_crate;
use pipewire::keys;
use pipewire::registry::GlobalObject;
use pipewire::spa::utils::dict::DictRef;
use pipewire::types::ObjectType;
use std::rc::Rc;

use pipewire::context::ContextRc;
use pipewire::core::{CoreRc, PW_ID_CORE};
use pipewire::loop_::Timeout;
use pipewire::main_loop::MainLoopRc;
use pipewire::properties::PropertiesBox;
use pipewire::spa::buffer::meta::MetaHeader;
use pipewire::spa::buffer::{meta::Metadata, DataType};
use pipewire::spa::param::format::{FormatProperties, MediaSubtype, MediaType};
use pipewire::spa::param::format_utils::parse_format;
use pipewire::spa::param::video::{VideoFormat, VideoInfoRaw};
use pipewire::spa::param::ParamType;
use pipewire::spa::pod::deserialize::PodDeserializer;
use pipewire::spa::pod::serialize::PodSerializer;
use pipewire::spa::pod::{self, ChoiceValue, Pod, PodPropFlags, Property, PropertyFlags};
use pipewire::spa::sys::{self, spa_meta_header};
use pipewire::spa::utils::{
    Choice, ChoiceEnum, ChoiceFlags, Direction, Fraction, Rectangle as SpaRectangle, SpaTypes,
};
use pipewire::stream::{StreamFlags, StreamListener, StreamRc, StreamState};
use pipewire::sys::{pw_buffer, pw_stream_queue_buffer, pw_stream_return_buffer};

use smithay::backend::allocator::dmabuf::Dmabuf;
use smithay::backend::allocator::Fourcc;
use smithay::backend::renderer::sync::SyncPoint;
use smithay::reexports::calloop::generic::Generic;
use smithay::reexports::calloop::{Interest, LoopHandle, Mode, PostAction, RegistrationToken};
use smithay::reexports::gbm::Modifier;
use smithay::utils::{Physical, Size};
use zbus::zvariant::OwnedObjectPath;

use super::shm::ShmBuffer;
use crate::backend::CaptureDmabufSetup;
use crate::portal::service::SourceKind;
use crate::state::State;
use crate::Backend;

/// Frame budget ceiling: the producer never advertises above this rate
/// regardless of consumer. With the dmabuf transport in place a frame costs
/// a GPU render and no CPU copy, so the ceiling can match a common display
/// refresh; consumers that ask for less still get less.
const MAX_FRAMERATE_NUM: u32 = 60;

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
    /// Last frame copy for this stream: the frame budget is enforced
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
    /// The dmabuf allocator and renderable formats, or None to stay on the
    /// shared-memory transport.
    dmabufs: Option<CaptureDmabufSetup>,
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

/// The buffer transport a stream negotiated: a dmabuf (GPU, zero-copy) or
/// the shared-memory fallback.
#[derive(Clone, Copy, Debug)]
enum StreamTransport {
    /// The consumer fixated a dmabuf modifier; buffers are allocated by the
    /// producer and rendered into directly.
    Dmabuf { modifier: Modifier },
    /// The consumer only understands shared memory; the producer allocates
    /// sealed memfds and copies rendered frames in.
    Shm,
}

/// The result of submitting a rendered dmabuf frame to the producer.
pub enum FrameQueue {
    /// The buffer was queued to the consumer immediately (the render fence
    /// had already signaled, or none was exportable).
    Queued,
    /// The render fence had not signaled; the buffer is held until the
    /// caller reports the fence readable and calls
    /// [`Producer::queue_deferred_frame`].
    Deferred { id: u64, fence: OwnedFd },
}

/// Mutable producer state shared with the PipeWire callbacks.
struct StreamInner {
    descriptor: StreamDescriptor,
    /// Negotiated buffer size; None until the SPA fixated the format.
    ready_size: Option<Size<i32, Physical>>,
    node_id: Option<u32>,
    /// Chosen after format negotiation; None until the transport settles.
    transport: Option<StreamTransport>,
    /// Producer-owned dmabufs keyed by the first plane's fd (the fd the
    /// producer advertises in the SPA buffer).
    dmabufs: HashMap<i64, Dmabuf>,
    /// Producer-owned shared-memory buffers keyed by their memfd.
    shmbufs: HashMap<i64, ShmBuffer>,
    /// Monotonic frame sequence stamped into the SPA header.
    sequence: u64,
    /// Dequeued dmabufs whose render fence has not signaled yet, keyed by a
    /// monotonic id. [`Producer::queue_deferred_frame`] releases them to the
    /// consumer once the fence fires.
    pending: HashMap<u64, NonNull<pw_buffer>>,
    /// Next id handed to a deferred frame.
    next_pending: u64,
}

// The maps hold GPU/CPU buffers; all access happens on the compositor loop
// thread, but PipeWire's raw callbacks force the `Send` bound on the state.
unsafe impl Send for StreamInner {}

fn make_pod(buffer: &mut Vec<u8>, object: pod::Object) -> &Pod {
    PodSerializer::serialize(Cursor::new(&mut *buffer), &pod::Value::Object(object))
        .expect("pod serialization is infallible in memory");
    Pod::from_bytes(buffer).expect("pod rehydration from owned memory")
}

/// One format offer: RGBA only, fixed size, framerate parameterized by the
/// output refresh, capped at [`MAX_FRAMERATE_NUM`]. A non-empty `modifiers`
/// list yields the dmabuf variant (with a modifier choice the consumer
/// fixates); an empty list yields the shared-memory variant.
fn make_video_params_object(size: Size<i32, Physical>, modifiers: &[Modifier]) -> pod::Object {
    let mut properties = vec![
        pod::property!(FormatProperties::MediaType, Id, MediaType::Video),
        pod::property!(FormatProperties::MediaSubtype, Id, MediaSubtype::Raw),
        // RGBA byte order matches the compositor readback exactly: the
        // Abgr8888 framebuffer maps back as R,G,B,A bytes, and the first
        // real session streamed red/blue-swapped when a BGRx declare was
        // negotiated against those bytes.
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
        // The consumer passes on a rate it can keep up with; the producer
        // never promises above MAX_FRAMERATE_NUM.
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
    ];

    if !modifiers.is_empty() {
        // With several modifiers the daemon must not pick one for us: it
        // reports DONT_FIXATE, we test-allocate, and we answer with the
        // single modifier that works on this renderer.
        let dont_fixate = if modifiers.len() > 1 {
            PropertyFlags::from_bits_retain(sys::SPA_POD_PROP_FLAG_DONT_FIXATE)
        } else {
            PropertyFlags::empty()
        };
        let alternatives = modifiers
            .iter()
            .map(|modifier| u64::from(*modifier) as i64)
            .collect::<Vec<_>>();
        properties.push(Property {
            key: FormatProperties::VideoModifier.as_raw(),
            flags: PropertyFlags::MANDATORY | dont_fixate,
            value: pod::Value::Choice(ChoiceValue::Long(Choice(
                ChoiceFlags::empty(),
                ChoiceEnum::Enum {
                    default: alternatives[0],
                    alternatives,
                },
            ))),
        });
    }

    pod::Object {
        type_: SpaTypes::ObjectParamFormat.as_raw(),
        id: ParamType::EnumFormat.as_raw(),
        properties,
    }
}

/// The initial EnumFormat offer for a stream: the dmabuf variant first
/// (when the backend can allocate one), then the always-available
/// shared-memory variant. The consumer's fixation decides the transport,
/// which is how the SHM fallback is reached without reconnecting.
fn make_initial_video_params(
    size: Size<i32, Physical>,
    modifiers: &[Modifier],
) -> Vec<pod::Object> {
    let mut params = Vec::new();
    if !modifiers.is_empty() {
        params.push(make_video_params_object(size, modifiers));
    }
    params.push(make_video_params_object(size, &[]));
    params
}

/// The Buffers params for a negotiated transport: the data type flags and
/// the plane count. The producer allocates the buffers itself
/// (`PW_STREAM_FLAG_ALLOC_BUFFERS`), so no size/stride is declared here.
fn buffers_object(plane_count: usize, dma: bool) -> pod::Object {
    let data_type = if dma {
        DataType::DmaBuf
    } else {
        DataType::MemFd
    };
    let flags = 1 << data_type.as_raw();
    pod::object!(
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
        Property::new(
            sys::SPA_PARAM_BUFFERS_blocks,
            pod::Value::Int(plane_count as i32),
        ),
        Property::new(
            sys::SPA_PARAM_BUFFERS_dataType,
            pod::Value::Choice(ChoiceValue::Int(Choice(
                ChoiceFlags::empty(),
                ChoiceEnum::Flags {
                    default: flags,
                    flags: vec![flags],
                }
            ))),
        ),
    )
}

/// The Meta params: the SPA header carries the frame sequence and a
/// "timestamp unknown" marker. Presentation timestamps are deliberately
/// not invented here; elapsed time is not part of the sharing contract.
fn header_meta_object() -> pod::Object {
    pod::object!(
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
    )
}

/// Picks the first offered modifier that actually allocates on this
/// renderer. Returning the modifier a consumer proposed is what lets the
/// fixate handshake commit to a format that can really be rendered.
fn choose_modifier(
    allocator: &dyn crate::backend::CaptureDmabufAllocator,
    size: Size<i32, Physical>,
    alternatives: &[i64],
) -> Option<Modifier> {
    alternatives.iter().find_map(|raw| {
        let modifier = Modifier::from(*raw as u64);
        allocator
            .allocate(size.w as u32, size.h as u32, Fourcc::Abgr8888, &[modifier])
            .ok()
            .map(|_| modifier)
    })
}

impl Producer {
    /// Connects to the user's session PipeWire daemon and registers the
    /// PipeWire main loop FD into calloop, dispatching without blocking.
    pub fn new<BackendData: Backend + 'static>(
        loop_handle: &LoopHandle<'static, State<BackendData>>,
        to_loop: smithay::reexports::calloop::channel::Sender<ProducerEvent>,
        dmabufs: Option<CaptureDmabufSetup>,
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
            dmabufs,
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
            transport: None,
            dmabufs: HashMap::new(),
            shmbufs: HashMap::new(),
            sequence: 0,
            pending: HashMap::new(),
            next_pending: 0,
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
        let to_loop_buffers = to_loop.clone();
        let lock = inner.clone();
        let lock_params = inner.clone();
        let lock_buffers = inner.clone();
        let lock_remove = inner.clone();
        // The GBM allocator lives for the callbacks, which run on the
        // compositor loop thread during `iterate`.
        let dmabufs = self.dmabufs.clone();
        let dmabufs_buffers = dmabufs.clone();

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

                let mut format = VideoInfoRaw::new();
                if format.parse(pod).is_err() {
                    fatal("error parsing the negotiated format".to_string());
                    return;
                }
                if format.format() != VideoFormat::RGBA {
                    fatal("pipewire negotiated away RGBA; stream unusable".to_string());
                    return;
                }
                let negotiated_size = Size::<i32, Physical>::from((
                    format.size().width as i32,
                    format.size().height as i32,
                ));

                let expected = lock_params.borrow().descriptor.size;
                if negotiated_size != expected {
                    fatal("negotiated size does not match the output size".to_string());
                    return;
                }

                // The transport follows from whether the fixated format
                // carries a dmabuf modifier: present means the dmabuf path,
                // absent means the shared-memory fallback the offer always
                // includes.
                let object = match pod.as_object() {
                    Ok(object) => object,
                    Err(_) => {
                        fatal("pipewire sent a format without an object".to_string());
                        return;
                    }
                };
                let modifier_prop =
                    object.find_prop(pipewire::spa::utils::Id(FormatProperties::VideoModifier.0));

                let plane_count = match modifier_prop {
                    // Several modifiers were offered; the daemon refused to
                    // pick one. Test-allocate and answer with the single
                    // modifier that really works here, then wait for the
                    // follow-up param_changed that fixates it.
                    Some(prop) if prop.flags().contains(PodPropFlags::DONT_FIXATE) => {
                        let Some(setup) = dmabufs.as_ref() else {
                            fatal(
                                "pipewire proposed a dmabuf modifier without a GBM device"
                                    .to_string(),
                            );
                            return;
                        };
                        let Ok((_, choice)) = PodDeserializer::deserialize_from::<Choice<i64>>(
                            prop.value().as_bytes(),
                        ) else {
                            fatal("unparsable dmabuf modifier list".to_string());
                            return;
                        };
                        let ChoiceEnum::Enum { alternatives, .. } = choice.1 else {
                            fatal("dmabuf modifiers were not offered as an enum".to_string());
                            return;
                        };
                        let Some(modifier) =
                            choose_modifier(&*setup.allocator, expected, &alternatives)
                        else {
                            fatal("no offered dmabuf modifier can be rendered here".to_string());
                            return;
                        };
                        let fixed = make_video_params_object(expected, &[modifier]);
                        let mut b0 = Vec::new();
                        let mut b1 = Vec::new();
                        let pods = &mut [
                            make_pod(&mut b0, fixed),
                            make_pod(&mut b1, make_video_params_object(expected, &[])),
                        ];
                        if let Err(error) = stream.update_params(pods) {
                            tracing::warn!("error fixing the dmabuf modifier: {error:?}");
                        }
                        return;
                    }
                    // A single or already-fixated modifier: prove the
                    // renderer can render into it, then commit to dmabuf.
                    Some(_) => {
                        let modifier = Modifier::from(format.modifier());
                        let Some(setup) = dmabufs.as_ref() else {
                            fatal("pipewire negotiated a dmabuf without a GBM device".to_string());
                            return;
                        };
                        match setup.allocator.allocate(
                            expected.w as u32,
                            expected.h as u32,
                            Fourcc::Abgr8888,
                            &[modifier],
                        ) {
                            Ok(dmabuf) => dmabuf.num_planes(),
                            Err(error) => {
                                fatal(format!("unusable dmabuf modifier: {error}"));
                                return;
                            }
                        }
                    }
                    None => 1,
                };
                let dma = modifier_prop.is_some();
                let modifier = Modifier::from(format.modifier());
                {
                    let mut inner = lock_params.borrow_mut();
                    inner.ready_size = Some(expected);
                    inner.transport = Some(if dma {
                        StreamTransport::Dmabuf { modifier }
                    } else {
                        StreamTransport::Shm
                    });
                    tracing::info!(
                        session = %inner.descriptor.session_handle,
                        dma,
                        plane_count,
                        modifier = ?modifier,
                        "screen-cast transport negotiated"
                    );
                }

                let buffers = buffers_object(plane_count, dma);
                // Only the SPA header is advertised. `SPA_META_VideoDamage`
                // is deliberately absent: Veshell has no sub-region damage
                // source yet (see free-explorers/veshell#63), so advertising
                // it would either always report the whole output or, worse,
                // risk stale regions. Every frame is sent fully damaged.
                let meta = header_meta_object();
                let mut b1 = Vec::new();
                let mut b2 = Vec::new();
                let pods = &mut [make_pod(&mut b1, buffers), make_pod(&mut b2, meta)];
                if let Err(error) = stream.update_params(pods) {
                    tracing::warn!("error updating stream params: {error:?}");
                }
            })
            .add_buffer(move |_, (), buffer| {
                // The producer allocates every buffer itself
                // (ALLOC_BUFFERS): a GPU dmabuf to render into, or a sealed
                // memfd to copy rendered frames into. Both are keyed by the
                // fd PipeWire hands back on dequeue.
                unsafe {
                    let spa_buffer = (*buffer).buffer;
                    if (*spa_buffer).n_datas < 1 || (*spa_buffer).datas.is_null() {
                        tracing::warn!("spa buffer has no data planes");
                        return;
                    }
                    let mut inner = lock_buffers.borrow_mut();
                    let size = inner.descriptor.size;
                    match inner.transport {
                        Some(StreamTransport::Dmabuf { modifier }) => {
                            let Some(setup) = dmabufs_buffers.as_ref() else {
                                return;
                            };
                            let dmabuf = match setup.allocator.allocate(
                                size.w as u32,
                                size.h as u32,
                                Fourcc::Abgr8888,
                                &[modifier],
                            ) {
                                Ok(dmabuf) => dmabuf,
                                Err(error) => {
                                    let session_handle =
                                        inner.descriptor.session_handle.clone();
                                    drop(inner);
                                    let _ = to_loop_buffers.send(ProducerEvent::Fatal {
                                        session_handle,
                                        message: format!(
                                            "Unable to allocate a screen-cast dmabuf: {error}"
                                        ),
                                    });
                                    return;
                                }
                            };
                            let plane_count = dmabuf.num_planes();
                            if ((*spa_buffer).n_datas as usize) < plane_count {
                                tracing::warn!("spa buffer has fewer planes than the dmabuf");
                                return;
                            }
                            for (i, (fd, (stride, offset))) in dmabuf
                                .handles()
                                .zip(dmabuf.strides().zip(dmabuf.offsets()))
                                .enumerate()
                            {
                                let spa_data = (*spa_buffer).datas.add(i);
                                (*spa_data).type_ = DataType::DmaBuf.as_raw();
                                // dma-buf consumers ignore maxsize; some
                                // legacy ones only check it is non-zero.
                                (*spa_data).maxsize = 1;
                                (*spa_data).fd = fd.as_raw_fd() as i64;
                                (*spa_data).flags = sys::SPA_DATA_FLAG_READWRITE;
                                let chunk = (*spa_data).chunk;
                                (*chunk).stride = stride as i32;
                                (*chunk).offset = offset;
                            }
                            let fd = (*(*spa_buffer).datas).fd;
                            inner.dmabufs.insert(fd, dmabuf);
                            tracing::debug!(
                                modifier = ?modifier,
                                plane_count,
                                "allocated screen-cast dmabuf"
                            );
                        }
                        Some(StreamTransport::Shm) => {
                            let shmbuf = match ShmBuffer::allocate(size.w as u32, size.h as u32) {
                                Ok(shmbuf) => shmbuf,
                                Err(error) => {
                                    let session_handle =
                                        inner.descriptor.session_handle.clone();
                                    drop(inner);
                                    let _ = to_loop_buffers.send(ProducerEvent::Fatal {
                                        session_handle,
                                        message: format!(
                                            "Unable to allocate a screen-cast buffer: {error}"
                                        ),
                                    });
                                    return;
                                }
                            };
                            let spa_data = (*spa_buffer).datas;
                            (*spa_data).type_ = DataType::MemFd.as_raw();
                            (*spa_data).maxsize = shmbuf.size;
                            (*spa_data).fd = shmbuf.as_raw_fd() as i64;
                            (*spa_data).flags = sys::SPA_DATA_FLAG_READWRITE;
                            let chunk = (*spa_data).chunk;
                            (*chunk).stride = shmbuf.stride;
                            (*chunk).offset = 0;
                            let fd = (*spa_data).fd;
                            tracing::debug!(
                                stride = shmbuf.stride,
                                size = shmbuf.size,
                                "allocated screen-cast shm buffer"
                            );
                            inner.shmbufs.insert(fd, shmbuf);
                        }
                        None => {}
                    }
                }
            })
            .remove_buffer(move |_, (), buffer| unsafe {
                let spa_buffer = (*buffer).buffer;
                if (*spa_buffer).n_datas < 1 || (*spa_buffer).datas.is_null() {
                    return;
                }
                let fd = (*(*spa_buffer).datas).fd;
                let mut inner = lock_remove.borrow_mut();
                inner.dmabufs.remove(&fd);
                inner.shmbufs.remove(&fd);
            })
            .register()
            .map_err(|error| format!("attach stream listener: {error}"))
            .expect("stream listener is supported by the PipeWire contract");

        let entry = self
            .streams
            .get_mut(session_handle)
            .expect("stream entry was just inserted");
        entry.listener = Some(listener);

        // Offer the dmabuf variant (monitor shares on a GBM backend) plus
        // the shared-memory variant; the consumer's fixation picks the
        // transport. The producer allocates the buffers (ALLOC_BUFFERS), so
        // no daemon-side memory allocation is involved.
        let modifiers: Vec<Modifier> = match (&self.dmabufs, descriptor.source_kind) {
            (Some(setup), SourceKind::Monitor) => setup
                .formats
                .iter()
                .map(|(_fourcc, modifier)| *modifier)
                .collect(),
            _ => Vec::new(),
        };
        let objects = make_initial_video_params(descriptor.size, &modifiers);
        let mut buffers: Vec<Vec<u8>> = objects.iter().map(|_| Vec::new()).collect();
        let mut pods: Vec<&Pod> = objects
            .iter()
            .zip(buffers.iter_mut())
            .map(|(object, buffer)| make_pod(buffer, object.clone()))
            .collect();
        if let Err(error) = stream.connect(
            Direction::Output,
            None,
            // The producer allocates every buffer. Combined with the offers
            // above this is zero-copy when the consumer imports dmabufs,
            // and a sealed memfd copy otherwise. The driver role stays: the
            // shell drives the graph.
            StreamFlags::DRIVER | StreamFlags::ALLOC_BUFFERS,
            &mut pods,
        ) {
            let _ = self.to_loop.send(ProducerEvent::Fatal {
                session_handle: session_handle.clone(),
                message: format!("stream connect: {error:?}"),
            });
            self.streams.remove(session_handle);
        }
    }

    /// Copies a rendered frame into the shared-memory buffers of a session.
    /// Only used on the shared-memory transport; dmabuf sessions render
    /// directly through [`Producer::begin_dmabuf_frame`].
    pub fn queue_frame(&mut self, session_handle: OwnedObjectPath, pixels: &[u8]) {
        let Some(entry) = self.streams.get(&session_handle) else {
            return;
        };
        {
            let inner = entry.inner.borrow();
            if inner.ready_size.is_none() || !matches!(inner.transport, Some(StreamTransport::Shm))
            {
                // Not ready yet, or a dmabuf session whose frames render
                // straight into the GPU buffer.
                return;
            }
        }
        // Dequeue the buffer the consumer handed back for refill.
        let pw_buffer_ptr = unsafe { entry.stream.dequeue_raw_buffer() };
        let Some(pw_buffer_ptr) = std::ptr::NonNull::new(pw_buffer_ptr) else {
            return;
        };
        let inner = entry.inner.borrow();
        unsafe {
            let spa_buffer = (*pw_buffer_ptr.as_ptr()).buffer;
            let spa_data = (*spa_buffer).datas;
            let fd = (*spa_data).fd;
            let Some(shmbuf) = inner.shmbufs.get(&fd) else {
                pw_stream_return_buffer(entry.stream.as_raw_ptr(), pw_buffer_ptr.as_ptr());
                return;
            };
            // The frame geometry is fixed at negotiation: a size drift
            // means the output mode changed under the session, and a
            // truncated frame would reach the consumer as garbage.
            if pixels.len() != shmbuf.len() {
                let expected = shmbuf.len();
                let session_handle = inner.descriptor.session_handle.clone();
                drop(inner);
                let _ = self.to_loop.send(ProducerEvent::Fatal {
                    session_handle,
                    message: format!("frame is {} bytes, expected {expected}", pixels.len()),
                });
                pw_stream_return_buffer(entry.stream.as_raw_ptr(), pw_buffer_ptr.as_ptr());
                return;
            }
            shmbuf.copy_frame(pixels);
            let chunk = (*spa_data).chunk;
            (*chunk).offset = 0;
            (*chunk).stride = shmbuf.stride;
            (*chunk).size = shmbuf.size;
            (*chunk).flags = sys::SPA_CHUNK_FLAG_NONE as i32;
        }
        unsafe {
            pw_stream_queue_buffer(entry.stream.as_raw_ptr(), pw_buffer_ptr.as_ptr());
        }
    }

    /// Whether a live session negotiated the dmabuf transport.
    pub fn is_dmabuf_stream(&self, session_handle: &OwnedObjectPath) -> bool {
        self.streams.get(session_handle).is_some_and(|entry| {
            matches!(
                entry.inner.borrow().transport,
                Some(StreamTransport::Dmabuf { .. })
            )
        })
    }

    /// Dequeues a dmabuf buffer for the compositor to render into. The
    /// returned handle must be completed with
    /// [`Producer::finish_dmabuf_frame`].
    pub fn begin_dmabuf_frame(
        &mut self,
        session_handle: &OwnedObjectPath,
    ) -> Option<(Dmabuf, NonNull<pw_buffer>)> {
        let entry = self.streams.get(session_handle)?;
        if !matches!(
            entry.inner.borrow().transport,
            Some(StreamTransport::Dmabuf { .. })
        ) {
            return None;
        }
        let buffer = NonNull::new(unsafe { entry.stream.dequeue_raw_buffer() })?;
        let dmabuf = unsafe {
            let spa_buffer = (*buffer.as_ptr()).buffer;
            let fd = (*(*spa_buffer).datas).fd;
            entry.inner.borrow().dmabufs.get(&fd)?.clone()
        };
        Some((dmabuf, buffer))
    }

    /// Submits a buffer rendered into by [`Producer::begin_dmabuf_frame`].
    ///
    /// When the render fence has not signaled yet the buffer is held back
    /// (never handed to the consumer half-written); the caller must then
    /// call [`Producer::queue_deferred_frame`] once the returned fence is
    /// readable. `rendered` false marks the frame corrupted.
    pub fn finish_dmabuf_frame(
        &mut self,
        session_handle: &OwnedObjectPath,
        buffer: NonNull<pw_buffer>,
        rendered: bool,
        sync: Option<SyncPoint>,
    ) -> FrameQueue {
        let Some(entry) = self.streams.get(session_handle) else {
            return FrameQueue::Queued;
        };
        if rendered {
            if let Some(sync) = sync {
                if !sync.is_reached() {
                    if let Some(fence) = sync.export() {
                        let mut inner = entry.inner.borrow_mut();
                        let id = inner.next_pending;
                        inner.next_pending = inner.next_pending.wrapping_add(1);
                        inner.pending.insert(id, buffer);
                        tracing::debug!(id, "screen-cast frame deferred on its render fence");
                        return FrameQueue::Deferred { id, fence };
                    }
                }
            }
            // SAFETY: the buffer was dequeued from this stream and has not
            // been queued back yet.
            unsafe { mark_dmabuf_good_and_queue(entry, buffer) };
        } else {
            // SAFETY: as above.
            unsafe { mark_dmabuf_corrupted_and_queue(entry, buffer) };
        }
        FrameQueue::Queued
    }

    /// Releases a buffer held by [`Producer::finish_dmabuf_frame`] once its
    /// render fence has signaled.
    pub fn queue_deferred_frame(&mut self, session_handle: &OwnedObjectPath, id: u64) {
        let Some(entry) = self.streams.get(session_handle) else {
            return;
        };
        let buffer = entry.inner.borrow_mut().pending.remove(&id);
        if let Some(buffer) = buffer {
            tracing::debug!(id, "screen-cast deferred frame queued");
            // SAFETY: the buffer was dequeued from this stream and held
            // across the fence; it is queued back exactly once.
            unsafe { mark_dmabuf_good_and_queue(entry, buffer) };
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

/// Stamps a completed dmabuf frame and returns it to the consumer.
///
/// # Safety
///
/// `buffer` must be a dequeued, not-yet-requeued dmabuf buffer of `entry`.
unsafe fn mark_dmabuf_good_and_queue(entry: &StreamEntry, buffer: NonNull<pw_buffer>) {
    let spa_buffer = (*buffer.as_ptr()).buffer;
    let spa_data = (*spa_buffer).datas;
    let chunk = (*spa_data).chunk;
    // dma-buf consumers ignore size; some legacy ones want it non-zero.
    (*chunk).size = 1;
    (*chunk).flags = sys::SPA_CHUNK_FLAG_NONE as i32;
    let mut inner = entry.inner.borrow_mut();
    inner.sequence = inner.sequence.wrapping_add(1);
    if let Some(header) = find_meta_header(spa_buffer) {
        let header = header.as_ptr();
        (*header).flags = 0;
        (*header).seq = inner.sequence;
        // Presentation timestamps are unknown, never invented.
        (*header).pts = -1;
    }
    drop(inner);
    pw_stream_queue_buffer(entry.stream.as_raw_ptr(), buffer.as_ptr());
}

/// Marks a failed frame corrupted and returns it to the consumer so the
/// buffer is not lost.
///
/// # Safety
///
/// As [`mark_dmabuf_good_and_queue`].
unsafe fn mark_dmabuf_corrupted_and_queue(entry: &StreamEntry, buffer: NonNull<pw_buffer>) {
    let spa_buffer = (*buffer.as_ptr()).buffer;
    let chunk = (*(*spa_buffer).datas).chunk;
    (*chunk).size = 0;
    (*chunk).flags = sys::SPA_CHUNK_FLAG_CORRUPTED as i32;
    if let Some(header) = find_meta_header(spa_buffer) {
        (*header.as_ptr()).flags = sys::SPA_META_HEADER_FLAG_CORRUPTED;
    }
    pw_stream_queue_buffer(entry.stream.as_raw_ptr(), buffer.as_ptr());
}

/// The SPA header of a dequeued buffer, when the consumer negotiated one.
///
/// # Safety
///
/// `buffer` must be a valid `spa_buffer` whose headers are initialised.
unsafe fn find_meta_header(buffer: *mut sys::spa_buffer) -> Option<NonNull<spa_meta_header>> {
    let header = sys::spa_buffer_find_meta_data(
        buffer,
        sys::SPA_META_Header,
        std::mem::size_of::<spa_meta_header>(),
    )
    .cast::<spa_meta_header>();
    NonNull::new(header)
}
