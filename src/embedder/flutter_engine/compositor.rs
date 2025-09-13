use std::ffi::c_void;

use smithay::backend::egl;
use smithay::backend::renderer::gles::ffi::Gles2;
use smithay::backend::renderer::gles::GlesError;
use smithay::reexports::calloop::channel::Event::Msg;
use smithay::{
    backend::allocator::dmabuf::Dmabuf,
    reexports::calloop::{channel, LoopHandle},
};
use tracing::debug;

use crate::flutter_engine::RendererData;
use crate::{
    backend::Backend,
    flutter_engine::{
        embedder::{
            FlutterBackingStore, FlutterBackingStoreConfig,
            FlutterBackingStoreType_kFlutterBackingStoreTypeOpenGL,
            FlutterBackingStore__bindgen_ty_1, FlutterCompositor, FlutterOpenGLBackingStore,
            FlutterOpenGLBackingStore__bindgen_ty_1, FlutterOpenGLFramebuffer,
            FlutterOpenGLTargetType_kFlutterOpenGLTargetTypeFramebuffer, FlutterPresentViewInfo,
        },
        FlutterEngine,
    },
    gles_framebuffer_importer::GlesFramebufferImporter,
    state::State,
};
type ImportBufferCallback = fn(dmabuf: Dmabuf) -> Result<u32, GlesError>;

pub struct CompositorUserData {
    pub tx_request_buffer: channel::Sender<FlutterBackingStoreConfig>,
    pub rx_on_buffer_sent: channel::Channel<Option<Dmabuf>>,
    pub tx_present_view: channel::Sender<i64>,
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
        let (tx_send_buffer, rx_on_buffer_sent) = channel::channel::<Option<Dmabuf>>();
        let (tx_request_buffer, rx_on_buffer_requested) =
            channel::channel::<FlutterBackingStoreConfig>();
        let (tx_present_view, rx_on_present_view) = channel::channel::<i64>();

        loop_handle
            .insert_source(rx_on_buffer_requested, move |config, _, data| {
                if let Msg(config) = config {
                    let flutter_engine = data.flutter_engine_mut();
                    let view = flutter_engine
                        .views_management
                        .views
                        .get_mut(&config.view_id)
                        .unwrap();

                    let dmabuf = view.acquire_dmabuf();

                    tx_send_buffer.send(Some(dmabuf)).unwrap();
                }
            })
            .unwrap();

        loop_handle
            .insert_source(rx_on_present_view, move |view_id, _, data| {
                debug!("rx_on_present_view");

                if let Msg(view_id) = view_id {
                    let flutter_engine = data.flutter_engine_mut();
                    let view = flutter_engine
                        .views_management
                        .views
                        .get_mut(&view_id)
                        .unwrap();

                    view.last_rendered_slot = view.current_slot.take();

                    if let Some(ref slot) = view.last_rendered_slot {
                        view.swapchain.submitted(slot);
                    }
                }
            })
            .unwrap();

        let user_data = Box::into_raw(Box::new(CompositorUserData {
            tx_request_buffer,
            rx_on_buffer_sent,
            tx_present_view,
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
    debug!("create_backing_store_callback");
    let compositor_data = &mut *(user_data as *mut CompositorUserData);
    let flutter_engine =
        &mut *(compositor_data.flutter_engine_ptr as *mut FlutterEngine<BackendData>);
    if compositor_data.tx_request_buffer.send(*config).is_err() {
        return false;
    }

    if let Ok(Some(dmabuf)) = compositor_data.rx_on_buffer_sent.recv() {
        let name = flutter_engine
            .renderer_data
            .framebuffer_importer
            .import_framebuffer(&flutter_engine.renderer_data.main_egl_context, dmabuf)
            .unwrap_or(0);

        *backing_store_out = FlutterBackingStore {
            struct_size: std::mem::size_of::<FlutterBackingStore>(),
            user_data: std::ptr::null_mut(),
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
    // TODO: ensure we don't have a memory leak there
    let compositor_data = &mut *(user_data as *mut CompositorUserData);

    true
}

pub unsafe extern "C" fn present_view_callback<BackendData>(
    info: *const FlutterPresentViewInfo,
) -> bool
where
    BackendData: Backend + 'static,
{
    debug!("present_view_callback");
    let user_data = (*info).user_data;
    let compositor_data = &mut *(user_data as *mut CompositorUserData);
    let flutter_engine =
        &mut *(compositor_data.flutter_engine_ptr as *mut FlutterEngine<BackendData>);
    flutter_engine.renderer_data.gl.Finish();
    compositor_data
        .tx_present_view
        .send((*info).view_id)
        .is_ok()
}
