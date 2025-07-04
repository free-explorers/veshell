use std::collections::{HashMap, HashSet};
use std::ffi::c_void;

use crate::flutter_engine::channel::Event::Msg;
use crate::flutter_engine::embedder::{
    FlutterAddViewInfo, FlutterAddViewResult, FlutterEngineAddView, FlutterWindowMetricsEvent,
};
use crate::{backend::Backend, flutter_engine::FlutterEngine};
use smithay::backend::allocator::dmabuf::{AnyError, Dmabuf};
use smithay::backend::allocator::{Allocator, Slot, Swapchain};
use smithay::reexports::calloop::{self, channel};
use smithay::reexports::winit::event;
use smithay::utils::SerialCounter;
use tracing::debug;

pub struct ViewsManagement {
    serials: SerialCounter,
    pub views: HashMap<i64, VeshellView>,
}

impl ViewsManagement {
    pub fn new() -> Self {
        Self {
            serials: SerialCounter::new(),
            views: HashMap::new(),
        }
    }
}

struct VeshellView {
    view_id: i64,
    pub swapchain: Swapchain<Box<dyn Allocator<Buffer = Dmabuf, Error = AnyError> + 'static>>,
    pub current_slot: Option<Slot<Dmabuf>>,
    pub last_rendered_slot: Option<Slot<Dmabuf>>,
}

struct AddViewData {
    tx_done: channel::Sender<(i64, bool)>,
    view_id: i64,
}

impl<BackendData: Backend + 'static> FlutterEngine<BackendData> {
    pub fn add_view(&mut self, display_id: u64, width: usize, height: usize) -> i64 {
        let (tx_done, rx_done) = channel::channel::<(i64, bool)>();

        let serial: u32 = self.views_management.serials.next_serial().into();
        let view_id: i64 = serial as i64;

        let add_view_data = Box::new(AddViewData { tx_done, view_id });
        let result = unsafe {
            FlutterEngineAddView(
                self.handle,
                &FlutterAddViewInfo {
                    struct_size: size_of::<FlutterAddViewInfo>(),
                    view_id,
                    view_metrics: &FlutterWindowMetricsEvent {
                        struct_size: size_of::<FlutterWindowMetricsEvent>(),
                        width,
                        height,
                        pixel_ratio: 1.,
                        left: 0,
                        top: 0,
                        physical_view_inset_top: 0.,
                        physical_view_inset_right: 0.,
                        physical_view_inset_bottom: 0.,
                        physical_view_inset_left: 0.,
                        display_id: display_id,
                        view_id,
                    },
                    user_data: Box::into_raw(add_view_data) as *mut c_void,
                    add_view_callback: Some(add_view_callback::<BackendData>),
                },
            )
        };

        self.loop_handle
            .insert_source(rx_done, move |event, _, data| {
                debug!("add_view_callback: {:?}", event);
                if let Msg((event_view_id, added)) = event {
                    if added {
                        let view = VeshellView {
                            view_id: event_view_id,
                            swapchain: data.backend_data.new_swapchain(2000, 2000),
                            current_slot: None,
                            last_rendered_slot: None,
                        };
                        data.flutter_engine_mut()
                            .views_management
                            .views
                            .insert(view_id, view);
                    }
                }
            })
            .unwrap();

        view_id
    }

    pub fn resizeView(&self, view_id: i64, width: u32, height: u32) {
        // send new metrics to flutter engine

        //resize the swapchain
    }
}

pub unsafe extern "C" fn add_view_callback<BackendData>(result: *const FlutterAddViewResult)
where
    BackendData: Backend + 'static,
{
    debug!("add_view_callback: {:?}", result);
    let result = &*result;
    let add_view_data = &mut *(result.user_data as *mut AddViewData);
    add_view_data
        .tx_done
        .send((add_view_data.view_id, result.added))
        .unwrap();
}
