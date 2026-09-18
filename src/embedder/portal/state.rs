//! Portal-owned state carried by the compositor [State](crate::state::State):
//! the running xdg-desktop-portal backend, its capture/encode bridge, and the
//! PipeWire producer and live screen-cast streams.

use std::collections::HashMap;

use smithay::reexports::calloop::{channel, LoopHandle};
use tracing::{info, warn};
use zbus::zvariant::OwnedObjectPath;

use super::service::{insert_portal_capture_source, PortalCaptureOutcome};
use super::{spawn_portal_runtime, PortalRuntime};
use crate::capture::pipewire::{ActiveStream, Producer, ProducerEvent};
use crate::capture::PendingPortalPixels;
use crate::{Backend, State};

pub struct PortalState {
    pub runtime: Option<PortalRuntime>,
    pub capture_sender: channel::Sender<PortalCaptureOutcome>,
    pub pending_pixels: HashMap<u64, PendingPortalPixels>,
    pub pipewire_producer: Option<Producer>,
    pub producer_delivery_sender: channel::Sender<ProducerEvent>,
    pub active_streams: HashMap<OwnedObjectPath, ActiveStream>,
}

impl PortalState {
    pub fn new<BackendData: Backend + 'static>(
        loop_handle: &LoopHandle<'static, State<BackendData>>,
    ) -> Self {
        // Portal screenshot/pick-color captures report their outcome here
        // (encoder runs on a worker thread like the hotkey screenshot).
        let capture_sender = insert_portal_capture_source(loop_handle);
        // The PipeWire producer reports node life and failures over this
        // channel; the compositor loop answers with session lifecycle.
        let (producer_delivery_sender, producer_delivery_receiver) =
            channel::channel::<ProducerEvent>();
        loop_handle
            .insert_source(producer_delivery_receiver, |event, _, state| {
                if let channel::Event::Msg(receipt) = event {
                    super::service::handle_producer_event(state, receipt);
                }
            })
            .expect("Failed to init producer channel");

        // The portal backend is owned exclusively by the seat session: a
        // nested or foreign-bus run must never answer portal requests.
        let runtime = if <BackendData as Backend>::RUNS_PORTAL_BACKEND {
            match spawn_portal_runtime() {
                Some(Ok((runtime, calls))) => {
                    loop_handle
                        .insert_source(calls, |event, _, state: &mut State<BackendData>| {
                            if let channel::Event::Msg(call) = event {
                                super::service::handle_portal_call(state, call);
                            }
                        })
                        .expect("Failed to init portal call bridge");
                    info!("Portal backend listening on the session bus");
                    Some(runtime)
                }
                Some(Err(error)) => {
                    warn!(?error, "Portal backend did not start");
                    None
                }
                None => {
                    warn!("No session bus is available for the portal backend");
                    None
                }
            }
        } else {
            None
        };

        Self {
            runtime,
            capture_sender,
            pending_pixels: HashMap::new(),
            pipewire_producer: None,
            producer_delivery_sender,
            active_streams: HashMap::new(),
        }
    }
}
