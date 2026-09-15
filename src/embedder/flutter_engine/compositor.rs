use std::ffi::c_void;

use crate::{
    backend::Backend,
    flutter_engine::{
        embedder::{
            FlutterBackingStore, FlutterBackingStoreConfig,
            FlutterBackingStoreType_kFlutterBackingStoreTypeOpenGL,
            FlutterBackingStore__bindgen_ty_1, FlutterCompositor,
            FlutterLayerContentType_kFlutterLayerContentTypeBackingStore,
            FlutterOpenGLBackingStore, FlutterOpenGLBackingStore__bindgen_ty_1,
            FlutterOpenGLFramebuffer, FlutterOpenGLTargetType_kFlutterOpenGLTargetTypeFramebuffer,
            FlutterPresentViewInfo,
        },
        view::{AcquiredBackingStore, BackingStoreId},
        FlutterEngine,
    },
    state::State,
};
use smithay::reexports::calloop::channel::Event::Msg;
use smithay::reexports::calloop::{channel, LoopHandle};
struct BackingStoreRequest {
    config: FlutterBackingStoreConfig,
    reply: channel::Sender<Option<AcquiredBackingStore>>,
}

enum BackingStoreEvent {
    Presented(BackingStoreId),
    Collected(BackingStoreId),
}

pub struct CompositorUserData {
    tx_request_buffer: channel::Sender<BackingStoreRequest>,
    tx_backing_store_event: channel::Sender<BackingStoreEvent>,
    flutter_engine_ptr: *mut c_void,
}

impl FlutterCompositor {
    pub fn new<BackendData>(
        loop_handle: &LoopHandle<'static, State<BackendData>>,
        flutter_engine_ptr: *mut c_void,
    ) -> Self
    where
        BackendData: Backend + 'static,
    {
        let (tx_request_buffer, rx_on_buffer_requested) = channel::channel::<BackingStoreRequest>();
        let (tx_backing_store_event, rx_on_backing_store_event) =
            channel::channel::<BackingStoreEvent>();

        loop_handle
            .insert_source(rx_on_buffer_requested, move |request, _, data| {
                if let Msg(request) = request {
                    let flutter_engine = data.flutter_engine_mut();
                    let backing_store = flutter_engine
                        .views_management
                        .views
                        .get_mut(&request.config.view_id)
                        .and_then(|view| view.acquire_backing_store());

                    if let Err(error) = request.reply.send(backing_store) {
                        if let Some(backing_store) = error.0 {
                            if let Some(view) = flutter_engine
                                .views_management
                                .views
                                .get_mut(&backing_store.id.view_id)
                            {
                                view.discard_backing_store(backing_store.id);
                            }
                        }
                    }
                }
            })
            .unwrap();

        loop_handle
            .insert_source(rx_on_backing_store_event, move |event, _, data| {
                if let Msg(event) = event {
                    // Snapshot the freeze flag first: the mutable engine
                    // borrow must not overlap it.
                    let freeze = data.capture_session.is_some();
                    let flutter_engine = data.flutter_engine_mut();
                    match event {
                        BackingStoreEvent::Presented(id) => {
                            // While a screenshot session freezes the
                            // desktop, late Flutter frames must not
                            // replace the frame captured at hotkey time.
                            if freeze {
                                if let Some(view) =
                                    flutter_engine.views_management.views.get_mut(&id.view_id)
                                {
                                    view.hold_backing_store(id);
                                }
                            } else if let Some(view) =
                                flutter_engine.views_management.views.get_mut(&id.view_id)
                            {
                                view.present_backing_store(id);
                            }
                        }
                        BackingStoreEvent::Collected(id) => {
                            if let Some(view) =
                                flutter_engine.views_management.views.get_mut(&id.view_id)
                            {
                                view.discard_backing_store(id);
                            }
                        }
                    }
                }
            })
            .unwrap();

        let user_data = Box::into_raw(Box::new(CompositorUserData {
            tx_request_buffer,
            tx_backing_store_event,
            flutter_engine_ptr,
        })) as *mut c_void;

        FlutterCompositor {
            struct_size: size_of::<FlutterCompositor>(),
            user_data,
            create_backing_store_callback: Some(create_backing_store_callback::<BackendData>),
            collect_backing_store_callback: Some(collect_backing_store_callback::<BackendData>),
            present_layers_callback: None,
            // Flutter must request another framebuffer every frame
            // because we're using a triple-buffered swapchain.
            avoid_backing_store_cache: true,
            present_view_callback: Some(present_view_callback::<BackendData>),
        }
    }
}

pub unsafe extern "C" fn create_backing_store_callback<BackendData>(
    config: *const FlutterBackingStoreConfig,
    backing_store_out: *mut FlutterBackingStore,
    user_data: *mut c_void,
) -> bool
where
    BackendData: Backend + 'static,
{
    if config.is_null() || backing_store_out.is_null() || user_data.is_null() {
        return false;
    }
    let compositor_data = &mut *(user_data as *mut CompositorUserData);
    let flutter_engine =
        &mut *(compositor_data.flutter_engine_ptr as *mut FlutterEngine<BackendData>);
    let (reply, response) = channel::channel::<Option<AcquiredBackingStore>>();
    if compositor_data
        .tx_request_buffer
        .send(BackingStoreRequest {
            config: *config,
            reply,
        })
        .is_err()
    {
        return false;
    }

    if let Ok(Some(backing_store)) = response.recv() {
        let name = flutter_engine
            .renderer_data
            .framebuffer_importer
            .import_framebuffer(
                &flutter_engine.renderer_data.main_egl_context,
                backing_store.dmabuf,
            )
            .unwrap_or(0);
        if name == 0 {
            let _ = compositor_data
                .tx_backing_store_event
                .send(BackingStoreEvent::Collected(backing_store.id));
            return false;
        }

        *backing_store_out = FlutterBackingStore {
            struct_size: std::mem::size_of::<FlutterBackingStore>(),
            user_data: Box::into_raw(Box::new(backing_store.id)) as *mut c_void,
            type_: FlutterBackingStoreType_kFlutterBackingStoreTypeOpenGL,
            did_update: true,
            __bindgen_anon_1: FlutterBackingStore__bindgen_ty_1 {
                open_gl: FlutterOpenGLBackingStore {
                    type_: FlutterOpenGLTargetType_kFlutterOpenGLTargetTypeFramebuffer,
                    __bindgen_anon_1: FlutterOpenGLBackingStore__bindgen_ty_1 {
                        framebuffer: FlutterOpenGLFramebuffer {
                            // RGBA8
                            target: 0x8058,
                            name: name,
                            user_data: std::ptr::null_mut(),
                            destruction_callback: None,
                        },
                    },
                },
            },
        }
    } else {
        return false;
    }
    true
}

pub unsafe extern "C" fn collect_backing_store_callback<BackendData>(
    renderer: *const FlutterBackingStore,
    user_data: *mut c_void,
) -> bool
where
    BackendData: Backend + 'static,
{
    if user_data.is_null() {
        return false;
    }
    let compositor_data = &mut *(user_data as *mut CompositorUserData);
    if renderer.is_null() {
        return false;
    }
    let backing_store_id = (*renderer).user_data as *mut BackingStoreId;
    if backing_store_id.is_null() {
        return false;
    }
    let backing_store_id = *Box::from_raw(backing_store_id);
    let _ = compositor_data
        .tx_backing_store_event
        .send(BackingStoreEvent::Collected(backing_store_id));

    true
}

pub unsafe extern "C" fn present_view_callback<BackendData>(
    info: *const FlutterPresentViewInfo,
) -> bool
where
    BackendData: Backend + 'static,
{
    if info.is_null() {
        return false;
    }
    let user_data = (*info).user_data;
    if user_data.is_null() || (*info).layers.is_null() || (*info).layers_count == 0 {
        return false;
    }
    let compositor_data = &mut *(user_data as *mut CompositorUserData);
    let flutter_engine =
        &mut *(compositor_data.flutter_engine_ptr as *mut FlutterEngine<BackendData>);
    flutter_engine.renderer_data.gl.Finish();
    let mut backing_store_id = None;
    for layer in std::slice::from_raw_parts((*info).layers, (*info).layers_count) {
        if layer.is_null() {
            return false;
        }
        let layer = &**layer;
        if layer.type_ != FlutterLayerContentType_kFlutterLayerContentTypeBackingStore {
            continue;
        }
        let backing_store = layer.__bindgen_anon_1.backing_store;
        if backing_store.is_null() {
            return false;
        }
        let id = (*backing_store).user_data as *const BackingStoreId;
        if id.is_null() || (*id).view_id != (*info).view_id {
            return false;
        }
        if backing_store_id.replace(*id).is_some() {
            return false;
        }
    }

    backing_store_id
        .and_then(|id| {
            compositor_data
                .tx_backing_store_event
                .send(BackingStoreEvent::Presented(id))
                .ok()
        })
        .is_some()
}
