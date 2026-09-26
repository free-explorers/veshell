use std::ffi::c_void;
use std::ptr::null_mut;

use serde_json::Value;
use smithay::backend::renderer::gles::ffi;
use smithay::reexports::calloop::channel;
use tracing::{debug, error};

use crate::backend::Backend;
use crate::flutter_engine::embedder::{
    FlutterAddViewResult, FlutterBackingStore, FlutterBackingStoreConfig,
    FlutterBackingStoreType_kFlutterBackingStoreTypeOpenGL, FlutterBackingStore__bindgen_ty_1,
    FlutterDamage, FlutterOpenGLBackingStore, FlutterOpenGLBackingStore__bindgen_ty_1,
    FlutterOpenGLFramebuffer, FlutterOpenGLTargetType_kFlutterOpenGLTargetTypeFramebuffer,
    FlutterOpenGLTexture, FlutterPlatformMessage, FlutterPresentInfo, FlutterPresentViewInfo,
    FlutterRect, FlutterTask, FlutterTransformation, FlutterViewFocusChangeRequest,
    FlutterViewFocusState_kFocused,
};
use crate::flutter_engine::platform_channels::basic_message_channel::BasicMessageChannel;
use crate::flutter_engine::platform_channels::binary_messenger::BinaryMessenger;
use crate::flutter_engine::platform_channels::json_message_codec::JsonMessageCodec;
use crate::flutter_engine::platform_channels::message_codec::MessageCodec;
use crate::flutter_engine::{Baton, FlutterEngine};
use crate::keyboard::VeshellKeyEvent;

pub unsafe extern "C" fn make_current<BackendData>(user_data: *mut c_void) -> bool
where
    BackendData: Backend + 'static,
{
    let flutter_engine = &mut *(user_data as *mut FlutterEngine<BackendData>);
    match flutter_engine.renderer_data.main_egl_context.make_current() {
        Ok(()) => true,
        Err(err) => {
            error!("{}", err);
            false
        }
    }
}

pub unsafe extern "C" fn make_resource_current<BackendData>(user_data: *mut c_void) -> bool
where
    BackendData: Backend + 'static,
{
    let flutter_engine = &mut *(user_data as *mut FlutterEngine<BackendData>);
    match flutter_engine
        .renderer_data
        .resource_egl_context
        .make_current()
    {
        Ok(()) => true,
        Err(err) => {
            error!("{}", err);
            false
        }
    }
}

pub unsafe extern "C" fn clear_current<BackendData>(user_data: *mut c_void) -> bool
where
    BackendData: Backend + 'static,
{
    let flutter_engine = &mut *(user_data as *mut FlutterEngine<BackendData>);
    match flutter_engine.renderer_data.main_egl_context.unbind() {
        Ok(()) => true,
        Err(err) => {
            error!("{}", err);
            false
        }
    }
}

pub unsafe extern "C" fn fbo_callback<BackendData>(user_data: *mut c_void) -> u32
where
    BackendData: Backend + 'static,
{
    debug!("fbo_callback");

    0
}

pub unsafe extern "C" fn present_with_info<BackendData>(
    user_data: *mut c_void,
    _frame_present_info: *const FlutterPresentInfo,
) -> bool
where
    BackendData: Backend + 'static,
{
    true
}

pub unsafe extern "C" fn populate_existing_damage<BackendData>(
    _user_data: *mut c_void,
    _fbo_id: isize,
    existing_damage: *mut FlutterDamage,
) where
    BackendData: Backend + 'static,
{
    let existing_damage = &mut *existing_damage;
    existing_damage.struct_size = std::mem::size_of::<FlutterDamage>();
    existing_damage.num_rects = 1;

    // TODO: Implement proper damage tracking.
    // The Flutter engine docs says that if this callback is not implemented,
    // it will repaint the entire screen every frame, but it's false.
    // It's probably a bug in the Flutter engine, but until I implement proper damage tracking
    // we manually set the damage to the entire screen.
    static FLUTTER_RECT: FlutterRect = FlutterRect {
        left: 0.0,
        top: 0.0,
        right: 10000.0,
        bottom: 10000.0,
    };

    existing_damage.damage = &FLUTTER_RECT as *const _ as *mut _;
}

/// Transformation the engine applies to the rendering surface before drawing.
///
/// The engine invokes this once per view it rasterizes in a frame
/// (`Rasterizer::DrawToSurfaceUnsafe`), but the callback receives only
/// `user_data`: there is no view identifier and no way to associate a returned
/// value with a specific view. Any transform returned here is therefore
/// engine-global, while Veshell's views can have independent heights. A shared
/// `transY` would silently flip the wrong views, so this callback is
/// deliberately kept as the identity.
///
/// Backends that must correct the Flutter texture orientation (Flutter renders
/// with a bottom-left origin) do it at composite time via
/// [`Backend::FLIP_FLUTTER_TEXTURE`], which is applied per view and per
/// render target. Multi-output backends must not rely on this callback for a
/// per-view flip.
pub unsafe extern "C" fn surface_transformation<BackendData>(
    _user_data: *mut c_void,
) -> FlutterTransformation
where
    BackendData: Backend + 'static,
{
    FlutterTransformation {
        scaleX: 1.0,
        skewX: 0.0,
        transX: 0.0,
        skewY: 0.0,
        scaleY: 1.0,
        transY: 0.0,
        pers0: 0.0,
        pers1: 0.0,
        pers2: 1.0,
    }
}

pub unsafe extern "C" fn vsync_callback<BackendData>(
    user_data: *mut std::os::raw::c_void,
    baton: isize,
) where
    BackendData: Backend + 'static,
{
    let flutter_engine = &mut *(user_data as *mut FlutterEngine<BackendData>);
    let _ = flutter_engine
        .renderer_data
        .channels
        .tx_baton
        .send(Baton(baton));
}

pub unsafe extern "C" fn runs_task_on_current_thread_callback<BackendData>(
    user_data: *mut c_void,
) -> bool
where
    BackendData: Backend + 'static,
{
    let flutter_engine = &mut *(user_data as *mut FlutterEngine<BackendData>);
    flutter_engine.current_thread_id == std::thread::current().id()
}

pub unsafe extern "C" fn post_task_callback<BackendData>(
    task: FlutterTask,
    target_time: u64,
    user_data: *mut c_void,
) where
    BackendData: Backend + 'static,
{
    let flutter_engine = &mut *(user_data as *mut FlutterEngine<BackendData>);
    let timeout = flutter_engine.task_runner.enqueue_task(task, target_time);
    flutter_engine
        .task_runner
        .reschedule_timer
        .send(timeout)
        .unwrap();
}

pub unsafe extern "C" fn platform_message_callback<BackendData>(
    message: *const FlutterPlatformMessage,
    user_data: *mut c_void,
) where
    BackendData: Backend + 'static,
{
    let flutter_engine = &mut *(user_data as *mut FlutterEngine<BackendData>);
    let message = &*message;
    flutter_engine
        .binary_messenger
        .borrow_mut()
        .handle_message(message);
}

pub unsafe extern "C" fn gl_external_texture_frame_callback<BackendData>(
    user_data: *mut c_void,
    texture_id: i64,
    _width: usize,
    _height: usize,
    texture_out: *mut FlutterOpenGLTexture,
) -> bool
where
    BackendData: Backend + 'static,
{
    let flutter_engine = &mut *(user_data as *mut FlutterEngine<BackendData>);
    let channels: &mut super::FlutterEngineChannels = &mut flutter_engine.renderer_data.channels;

    let (texture_name, _) = channels
        .tx_request_external_texture_name
        .send(texture_id)
        .ok()
        .and_then(|()| channels.rx_external_texture_name.recv().ok())
        .unwrap_or((0, ffi::RGBA8));

    let texture_out = &mut *texture_out;

    // TODO: Don't hardcode the target.
    // If the texture is imported from a DMABUF, I think it the target should be GL_TEXTURE_EXTERNAL_OES.
    texture_out.target = ffi::TEXTURE_2D;
    texture_out.name = texture_name;
    // TODO: Should probably not hardcode the format in case the texture is not RGBA8.
    // I can't just assign the format obtained from the channel because it's BGRA_EXT and for some
    // reason it doesn't work while RGBA8 does.
    texture_out.format = ffi::RGBA8;
    texture_out.user_data = null_mut();
    texture_out.destruction_callback = None;
    texture_out.width = 0;
    texture_out.height = 0;

    texture_name != 0
}

pub struct FlutterKeyEventData {
    pub key_event: VeshellKeyEvent,
    pub tx_flutter_handled_key_event: channel::Sender<(VeshellKeyEvent, bool)>,
    pub key_event_channel: BasicMessageChannel<Value>,
    pub raw_key_event: Value,
}

pub unsafe extern "C" fn key_event_callback(handled: bool, user_data: *mut c_void) {
    // Flutter queues KeyData before responding. Send the legacy companion only
    // after this callback so the framework dispatches the queued KeyData.
    let data = Box::from_raw(user_data as *mut FlutterKeyEventData);
    debug!(?handled, "Flutter key data queued");

    let event = data.key_event;
    let tx = data.tx_flutter_handled_key_event.clone();
    data.key_event_channel.send(
        &data.raw_key_event,
        Some(Box::new(move |response: Option<&[u8]>| {
            let handled = response
                .and_then(|response| JsonMessageCodec::new().decode_message(response))
                .and_then(|message| message["handled"].as_bool())
                .unwrap_or(false);
            debug!(
                key_code = event.key_code.raw(),
                keysym = ?event.keysym,
                ?handled,
                "Flutter key event result",
            );
            tx.send((event, handled)).ok();
        })),
    );
}

// add view callback

/// Invoked by the engine when Flutter wants native view focus to move (for
/// example after a keyboard focus transition crossed Flutter views).
///
/// The compositor has no separate native window focus to move: it mirrors the
/// requested view into its own focus source of truth, which reports the new
/// focus back to the engine via `FlutterEngine::set_focused_view`.
pub unsafe extern "C" fn view_focus_change_request_callback<BackendData>(
    request: *const FlutterViewFocusChangeRequest,
    user_data: *mut c_void,
) where
    BackendData: Backend + 'static,
{
    let request = &*request;
    // Only the newly focused view drives the compositor focus; the losing view
    // is unfocused as part of the same transition.
    if request.state != FlutterViewFocusState_kFocused {
        return;
    }
    let flutter_engine = &mut *(user_data as *mut FlutterEngine<BackendData>);
    // Ignore requests for views the compositor does not own (e.g. the
    // implicit Flutter view or a view that was already removed).
    if !flutter_engine
        .views_management
        .views
        .contains_key(&request.view_id)
    {
        return;
    }
    flutter_engine.set_focused_view(Some(request.view_id));
}
