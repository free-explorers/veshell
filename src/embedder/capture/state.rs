//! Capture-owned state carried by the compositor [State](crate::state::State):
//! the active native selection session and the delivery channels that bring
//! background encode/recording work back onto the compositor loop.

use smithay::reexports::calloop::{channel, LoopHandle};

use super::recording::RecordingEvent;
use super::{
    insert_recording_delivery_source, insert_screenshot_delivery_source, CaptureSession,
    LiveRecording, ScreenshotDeliveryEvent,
};
use crate::{Backend, State};

pub struct CaptureState {
    pub session: Option<CaptureSession>,
    pub screenshot_delivery_sender: channel::Sender<ScreenshotDeliveryEvent>,
    pub recording_session: Option<LiveRecording>,
    pub recording_delivery_sender: channel::Sender<RecordingEvent>,
}

impl CaptureState {
    pub fn new<BackendData: Backend + 'static>(
        loop_handle: &LoopHandle<'static, State<BackendData>>,
    ) -> Self {
        Self {
            session: None,
            screenshot_delivery_sender: insert_screenshot_delivery_source(loop_handle),
            recording_session: None,
            recording_delivery_sender: insert_recording_delivery_source(loop_handle),
        }
    }
}
