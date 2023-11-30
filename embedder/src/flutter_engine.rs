use std::cell::RefCell;
use std::ffi::{c_int, CString};
use std::mem::{MaybeUninit, size_of};
use std::ops::DerefMut;
use std::os::unix::ffi::OsStrExt;
use std::ptr::{null, null_mut};
use std::rc::Rc;
use std::time::Duration;

use smithay::{
    backend::{
        allocator::dmabuf::Dmabuf,
        egl::{
            self,
            context::{GlAttributes, GlProfile, PixelFormatRequirements},
            EGLContext,
        },
        renderer::gles::ffi::Gles2,
    },
    reexports::calloop::channel,
    utils::{Physical, Size},
};
use smithay::backend::renderer::gles::ffi::RGBA8;
use smithay::reexports::calloop;
use smithay::reexports::calloop::{Dispatcher, LoopHandle};
use smithay::reexports::calloop::channel::Event::Msg;
use smithay::reexports::calloop::timer::{TimeoutAction, Timer};

use crate::{Backend, CalloopData, flutter_engine::{
    callbacks::{
        clear_current,
        fbo_callback,
        make_current,
        make_resource_current,
        present_with_info,
        surface_transformation,
    },
    embedder::{
        FLUTTER_ENGINE_VERSION,
        FlutterEngine as FlutterEngineHandle,
        FlutterEngineGetCurrentTime,
        FlutterEngineOnVsync,
        FlutterEngineSendWindowMetricsEvent,
        FlutterEngineShutdown,
        FlutterOpenGLRendererConfig,
        FlutterProjectArgs,
        FlutterRendererConfig,
        FlutterRendererConfig__bindgen_ty_1,
        FlutterWindowMetricsEvent,
    },
}, ServerState};
use crate::flutter_engine::callbacks::{gl_external_texture_frame_callback, platform_message_callback, populate_existing_damage, post_task_callback, runs_task_on_current_thread_callback, vsync_callback};
use crate::flutter_engine::embedder::{FlutterCustomTaskRunners, FlutterEngineAOTData, FlutterEngineAOTDataSource, FlutterEngineAOTDataSource__bindgen_ty_1, FlutterEngineAOTDataSourceType_kFlutterEngineAOTDataSourceTypeElfPath, FlutterEngineCreateAOTData, FlutterEngineInitialize, FlutterEngineMarkExternalTextureFrameAvailable, FlutterEngineRegisterExternalTexture, FlutterEngineRunInitialized, FlutterEngineRunTask, FlutterEngineSendPointerEvent, FlutterPointerEvent, FlutterTaskRunnerDescription};
use crate::flutter_engine::platform_channel_callbacks::platform_channel_method_handler;
use crate::flutter_engine::platform_channels::binary_messenger_impl::BinaryMessengerImpl;
use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_channel::MethodChannel;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::flutter_engine::platform_channels::standard_method_codec::StandardMethodCodec;
use crate::flutter_engine::task_runner::TaskRunner;
use crate::gles_framebuffer_importer::GlesFramebufferImporter;
use crate::mouse_button_tracker::MouseButtonTracker;

mod callbacks;
pub mod embedder;
pub mod platform_channels;
pub mod task_runner;
pub mod wayland_messages;
pub mod platform_channel_callbacks;

/// Wrap the handle for various safety reasons:
/// - Clone & Copy is willingly not implemented to avoid using the engine after being shut down.
/// - Send is not implemented because all its methods must be called from the thread the engine was created.
pub struct FlutterEngine<BackendData: Backend + 'static> {
    loop_handle: LoopHandle<'static, CalloopData<BackendData>>,
    pub handle: FlutterEngineHandle,
    data: FlutterEngineData,
    pub task_runner: TaskRunner,
    current_thread_id: std::thread::ThreadId,
    pub(crate) mouse_button_tracker: MouseButtonTracker,
    pub binary_messenger: Rc<RefCell<BinaryMessengerImpl>>,
    pub platform_method_channel: MethodChannel,
    rx_request_external_texture_name_registration_token: calloop::RegistrationToken,
}

/// I don't want people to clone it because it's UB to call [FlutterEngine::on_vsync] multiple times
/// with the same baton, which will most probably segfault.
pub struct Baton(isize);

impl<BackendData: Backend + 'static> FlutterEngine<BackendData> {
    pub fn new(server_state: &mut ServerState<BackendData>) -> Result<(Box<Self>, EmbedderChannels), Box<dyn std::error::Error>> {
        let (tx_present, rx_present) = channel::channel::<()>();
        let (tx_request_fbo, rx_request_fbo) = channel::channel::<()>();
        let (tx_fbo, rx_fbo) = channel::channel::<Option<Dmabuf>>();
        let (tx_output_height, rx_output_height) = channel::channel::<u16>();
        let (tx_baton, rx_baton) = channel::channel::<Baton>();
        let (tx_reschedule_task_runner_timer, rx_reschedule_task_runner_timer) = channel::channel::<Duration>();
        let (tx_request_external_texture_name, rx_request_external_texture_name) = channel::channel::<i64>();
        let (tx_external_texture_name, rx_external_texture_name) = channel::channel::<(u32, u32)>();

        let flutter_engine_channels = FlutterEngineChannels {
            tx_present,
            tx_request_fbo,
            rx_fbo,
            rx_output_height,
            tx_baton,
            tx_request_external_texture_name,
            rx_external_texture_name,
        };

        let embedder_channels = EmbedderChannels {
            rx_present,
            rx_request_fbo,
            tx_fbo,
            tx_output_height,
            rx_baton,
        };

        let arch = if cfg!(target_arch = "x86_64") {
            "x64"
        } else if cfg!(target_arch = "aarch64") {
            "arm64"
        } else {
            panic!("Unsupported architecture");
        };

        // Default build is debug if not specified.
        let flutter_engine_build = option_env!("FLUTTER_ENGINE_BUILD").unwrap_or("debug");

        let executable_path = std::fs::canonicalize("/proc/self/exe")?;
        let bundle_root = if option_env!("BUNDLE").is_some() {
            executable_path.parent().unwrap().display().to_string()
        } else {
            format!("../shell/build/linux/{arch}/{flutter_engine_build}/bundle")
        };

        let assets_path = CString::new(format!("{bundle_root}/data/flutter_assets"))?;
        let icu_data_path = CString::new(format!("{bundle_root}/data/icudtl.dat"))?;
        let executable_path = CString::new(executable_path.as_os_str().as_bytes())?;
        let observatory_port = CString::new("--observatory-port=12345")?;
        let disable_service_auth_codes = CString::new("--disable-service-auth-codes")?;

        let command_line_argv = [
            executable_path.as_ptr(),
            observatory_port.as_ptr(),
            disable_service_auth_codes.as_ptr(),
        ];

        let elf_path = CString::new(format!("{bundle_root}/lib/libapp.so"))?;
        let mut aot_data: FlutterEngineAOTData = null_mut();

        if flutter_engine_build != "debug" {
            let aot_data_source = FlutterEngineAOTDataSource {
                type_: FlutterEngineAOTDataSourceType_kFlutterEngineAOTDataSourceTypeElfPath,
                __bindgen_anon_1: FlutterEngineAOTDataSource__bindgen_ty_1 {
                    elf_path: elf_path.as_ptr(),
                },
            };
            let result = unsafe { FlutterEngineCreateAOTData(&aot_data_source as *const _, &mut aot_data as *mut _) };
            if result != 0 {
                return Err(format!("Could not create AOT data, error {result}").into());
            }
        }

        let gles_renderer = server_state.gles_renderer.as_ref().unwrap();
        let root_egl_context = gles_renderer.egl_context();

        // We need a pointer to the memory location before initializing the struct.
        let mut this = Box::new(MaybeUninit::<Self>::uninit());

        let task_runner_description = FlutterTaskRunnerDescription {
            struct_size: size_of::<FlutterTaskRunnerDescription>(),
            user_data: this.deref_mut() as *const _ as *mut _,
            runs_task_on_current_thread_callback: Some(runs_task_on_current_thread_callback::<BackendData>),
            post_task_callback: Some(post_task_callback::<BackendData>),
            identifier: 1,
        };

        let task_runners = FlutterCustomTaskRunners {
            struct_size: size_of::<FlutterCustomTaskRunners>(),
            platform_task_runner: &task_runner_description,
            render_task_runner: null(),
            thread_priority_setter: None,
        };

        let project_args = FlutterProjectArgs {
            struct_size: size_of::<FlutterProjectArgs>(),
            assets_path: assets_path.as_ptr(),
            main_path__unused__: null(),
            packages_path__unused__: null(),
            icu_data_path: icu_data_path.as_ptr(),
            command_line_argc: command_line_argv.len() as c_int,
            command_line_argv: command_line_argv.as_ptr(),
            platform_message_callback: Some(platform_message_callback::<BackendData>),
            vm_snapshot_data: null(),
            vm_snapshot_data_size: 0,
            vm_snapshot_instructions: null(),
            vm_snapshot_instructions_size: 0,
            isolate_snapshot_data: null(),
            isolate_snapshot_data_size: 0,
            isolate_snapshot_instructions: null(),
            isolate_snapshot_instructions_size: 0,
            root_isolate_create_callback: None,
            update_semantics_node_callback: None,
            update_semantics_custom_action_callback: None,
            persistent_cache_path: null(),
            is_persistent_cache_read_only: false,
            vsync_callback: Some(vsync_callback::<BackendData>),
            custom_dart_entrypoint: null(),
            custom_task_runners: &task_runners,
            shutdown_dart_vm_when_done: true,
            compositor: null(),
            dart_old_gen_heap_size: 0,
            aot_data,
            compute_platform_resolved_locale_callback: None,
            dart_entrypoint_argc: 0,
            dart_entrypoint_argv: null(),
            log_message_callback: None,
            log_tag: null(),
            on_pre_engine_restart_callback: None,
            update_semantics_callback: None,
            update_semantics_callback2: None,
            channel_update_callback: None,
        };

        let renderer_config = FlutterRendererConfig {
            type_: 0,
            __bindgen_anon_1: FlutterRendererConfig__bindgen_ty_1 {
                open_gl: FlutterOpenGLRendererConfig {
                    struct_size: size_of::<FlutterOpenGLRendererConfig>(),
                    make_current: Some(make_current::<BackendData>),
                    clear_current: Some(clear_current::<BackendData>),
                    present: None,
                    fbo_callback: Some(fbo_callback::<BackendData>),
                    make_resource_current: Some(make_resource_current::<BackendData>),
                    // Flutter must request another framebuffer every frame
                    // because we're using a triple-buffered swapchain.
                    fbo_reset_after_present: true,
                    surface_transformation: Some(surface_transformation::<BackendData>),
                    gl_proc_resolver: None,
                    gl_external_texture_frame_callback: Some(gl_external_texture_frame_callback::<BackendData>),
                    fbo_with_frame_info_callback: None,
                    present_with_info: Some(present_with_info::<BackendData>),
                    populate_existing_damage: Some(populate_existing_damage::<BackendData>),
                }
            },
        };

        let mut flutter_engine: FlutterEngineHandle = null_mut();
        let result = unsafe {
            FlutterEngineInitialize(
                FLUTTER_ENGINE_VERSION as usize,
                &renderer_config,
                &project_args,
                this.deref_mut() as *const _ as *mut _,
                &mut flutter_engine,
            )
        };
        if result != 0 {
            return Err(format!("Could not initalize the Flutter engine, error {result}").into());
        }

        let binary_messenger = Rc::new(RefCell::new(BinaryMessengerImpl::new(flutter_engine)));

        let codec = Rc::new(StandardMethodCodec::new());
        let mut platform_method_channel = MethodChannel::<EncodableValue>::new(
            binary_messenger.clone(),
            "platform".to_string(),
            codec,
        );

        let (tx_platform_message, rx_platform_message) = channel::channel::<(MethodCall, Box<dyn MethodResult>)>();
        // TODO: Provide a way to specify a channel directly, without registering a callback.
        platform_method_channel.set_method_call_handler(Some(Box::new(move |method_call, result| {
            tx_platform_message.send((method_call, result)).unwrap();
        })));

        server_state.loop_handle.insert_source(
            rx_platform_message,
            platform_channel_method_handler,
        ).unwrap();

        let task_runner_timer_dispatcher = Dispatcher::new(Timer::immediate(), move |deadline, _, data: &mut CalloopData<BackendData>| {
            let duration = data.state.flutter_engine_mut().task_runner.execute_expired_tasks(move |task| {
                unsafe { FlutterEngineRunTask(flutter_engine, task as *const _) };
            });
            TimeoutAction::ToDuration(duration)
        });
        let task_runner_timer_registration_token = server_state.loop_handle.register_dispatcher(task_runner_timer_dispatcher.clone()).unwrap();

        server_state.loop_handle.insert_source(rx_reschedule_task_runner_timer, move |event, _, data: &mut CalloopData<BackendData>| {
            if let Msg(duration) = event {
                task_runner_timer_dispatcher.as_source_mut().set_duration(duration);
                data.state.loop_handle.update(&task_runner_timer_registration_token).unwrap();
            }
        }).unwrap();

        let rx_request_external_texture_name_registration_token =
            server_state.loop_handle.insert_source(
                rx_request_external_texture_name,
                move |event, _, data| {
                    if let Msg(texture_id) = event {
                        let texture_swap_chain = data.state.texture_swapchains.get_mut(&texture_id);
                        let texture_id = match texture_swap_chain {
                            Some(texture) => {
                                let texture = texture.start_read();
                                texture.tex_id()
                            }
                            None => 0,
                        };
                        let _ = tx_external_texture_name.send((texture_id, RGBA8));
                    }
                }).unwrap();

        this.write(Self {
            loop_handle: server_state.loop_handle.clone(),
            handle: flutter_engine,
            data: FlutterEngineData::new(root_egl_context, flutter_engine_channels)?,
            task_runner: TaskRunner::new(tx_reschedule_task_runner_timer),
            current_thread_id: std::thread::current().id(),
            mouse_button_tracker: MouseButtonTracker::new(),
            binary_messenger: binary_messenger.clone(),
            platform_method_channel,
            rx_request_external_texture_name_registration_token,
        });

        // TODO: Delete this function once Box::assume_init gets stabilized.
        pub unsafe fn assume_init<T>(var: Box<MaybeUninit<T>>) -> Box<T> {
            let raw = Box::into_raw(var);
            unsafe { Box::from_raw(raw as *mut T) }
        }
        let this = unsafe { assume_init(this) };

        let result = unsafe { FlutterEngineRunInitialized(flutter_engine) };
        if result != 0 {
            return Err(format!("Could not run the Flutter engine, error {result}").into());
        }

        Ok((this, embedder_channels))
    }

    pub fn current_time_ns() -> u64 {
        unsafe { FlutterEngineGetCurrentTime() }
    }

    pub fn current_time_us() -> u64 {
        unsafe { FlutterEngineGetCurrentTime() / 1000 }
    }

    pub fn send_window_metrics(&self, size: Size<u32, Physical>) -> Result<(), Box<dyn std::error::Error>> {
        let event = FlutterWindowMetricsEvent {
            struct_size: size_of::<FlutterWindowMetricsEvent>(),
            width: size.w as usize,
            height: size.h as usize,
            pixel_ratio: 1.0,
            left: 0,
            top: 0,
            physical_view_inset_top: 0.0,
            physical_view_inset_right: 0.0,
            physical_view_inset_bottom: 0.0,
            physical_view_inset_left: 0.0,
            display_id: 0,
        };

        let result = unsafe { FlutterEngineSendWindowMetricsEvent(self.handle, &event as *const _) };
        if result != 0 {
            return Err(format!("Could not send window metrics event, error {result}").into());
        }
        Ok(())
    }

    pub fn on_vsync(&self, baton: Baton) -> Result<(), Box<dyn std::error::Error>> {
        let now = unsafe { FlutterEngineGetCurrentTime() };
        let next_frame = now + (1_000_000_000 / 144);
        let result = unsafe { FlutterEngineOnVsync(self.handle, baton.0, now, next_frame) };
        if result != 0 {
            return Err(format!("Could not send vsync baton, error {result}").into());
        }
        Ok(())
    }

    pub fn send_pointer_event(&self, event: FlutterPointerEvent) -> Result<(), Box<dyn std::error::Error>> {
        let result = unsafe { FlutterEngineSendPointerEvent(self.handle, &event as *const _, 1) };
        if result != 0 {
            return Err(format!("Could not send pointer event, error {result}").into());
        }
        Ok(())
    }

    pub fn register_external_texture(&self, texture_id: i64) -> Result<(), Box<dyn std::error::Error>> {
        let result = unsafe { FlutterEngineRegisterExternalTexture(self.handle, texture_id) };
        if result != 0 {
            return Err(format!("Could not register external texture, error {result}").into());
        }
        Ok(())
    }

    pub fn mark_external_texture_frame_available(&self, texture_id: i64) -> Result<(), Box<dyn std::error::Error>> {
        let result = unsafe { FlutterEngineMarkExternalTextureFrameAvailable(self.handle, texture_id) };
        if result != 0 {
            return Err(format!("Could not mark external texture frame available, error {result}").into());
        }
        Ok(())
    }
}

impl<BackendData: Backend + 'static> Drop for FlutterEngine<BackendData> {
    fn drop(&mut self) {
        if !self.handle.is_null() {
            // Avoid indefinite hang in the Flutter render thread waiting for an external texture.
            let token = self.rx_request_external_texture_name_registration_token;
            self.loop_handle.remove(token);
            let _ = unsafe { FlutterEngineShutdown(self.handle) };
        }
    }
}

struct FlutterEngineData {
    gl: Gles2,
    main_egl_context: EGLContext,
    resource_egl_context: EGLContext,
    output_height: Option<u16>,
    channels: FlutterEngineChannels,
    framebuffer_importer: GlesFramebufferImporter,
}

// Ironically, EGLContext which contains EGLDisplay is Send, but EGLDisplay is not.
// This impl is not needed, but it's here to make it explicit that it's safe to send this struct
// to the Flutter render thread.
unsafe impl Send for FlutterEngineData {}

impl FlutterEngineData {
    fn new(root_egl_context: &EGLContext, channels: FlutterEngineChannels) -> Result<Self, Box<dyn std::error::Error>> {
        unsafe { root_egl_context.make_current()? };

        let egl_display = root_egl_context.display();
        let gl_attributes = GlAttributes {
            version: (2, 0),
            profile: Some(GlProfile::Core),
            debug: false,
            vsync: false,
        };
        let pixel_format_requirements = PixelFormatRequirements::_8_bit();

        Ok(Self {
            gl: Gles2::load_with(|s| unsafe { egl::get_proc_address(s) } as *const _),
            main_egl_context: EGLContext::new_shared_with_config(&egl_display, &root_egl_context, gl_attributes, pixel_format_requirements)?,
            resource_egl_context: EGLContext::new_shared_with_config(&egl_display, &root_egl_context, gl_attributes, pixel_format_requirements)?,
            output_height: None,
            channels,
            framebuffer_importer: unsafe { GlesFramebufferImporter::new(egl_display.clone())? },
        })
    }
}

pub struct FlutterEngineChannels {
    tx_present: channel::Sender<()>,
    tx_request_fbo: channel::Sender<()>,
    rx_fbo: channel::Channel<Option<Dmabuf>>,
    rx_output_height: channel::Channel<u16>,
    tx_baton: channel::Sender<Baton>,
    tx_request_external_texture_name: channel::Sender<i64>,
    rx_external_texture_name: channel::Channel<(u32, u32)>,
}

pub struct EmbedderChannels {
    pub rx_present: channel::Channel<()>,
    pub rx_request_fbo: channel::Channel<()>,
    pub tx_fbo: channel::Sender<Option<Dmabuf>>,
    pub tx_output_height: channel::Sender<u16>,
    pub rx_baton: channel::Channel<Baton>,
}
