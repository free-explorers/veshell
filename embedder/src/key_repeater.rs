use std::time::{Duration, Instant};
use smithay::reexports::calloop;
use smithay::reexports::calloop::{LoopHandle, RegistrationToken, timer};
use smithay::reexports::calloop::timer::{TimeoutAction, Timer};
use crate::{Backend, CalloopData};

type Callback<BackendData> = fn(u32, Option<char>, Instant, &mut CalloopData<BackendData>);

pub struct KeyRepeater<BackendData: Backend + 'static> {
    loop_handle: LoopHandle<'static, CalloopData<BackendData>>,
    timer_token: Option<RegistrationToken>,
    callback: Callback<BackendData>,
}

impl<BackendData: Backend + 'static> KeyRepeater<BackendData> {
    pub fn new(loop_handle: LoopHandle<'static, CalloopData<BackendData>>, callback: Callback<BackendData>) -> Self {
        Self {
            loop_handle,
            timer_token: None,
            callback,
        }
    }

    pub fn down(&mut self, key_code: u32, char_point: Option<char>, delay: Duration, interval: Duration) {
        // Cancel any existing key repeat, we don't want to repeat multiple keys at once.
        self.up();

        let timer = Timer::from_duration(delay);

        let callback = self.callback.clone();
        let token = self.loop_handle.insert_source(timer, move |instant, _, data| {
            callback(key_code, char_point, instant, data);
            TimeoutAction::ToDuration(interval)
        }).unwrap();

        self.timer_token = Some(token);
    }

    pub fn up(&mut self) {
        if let Some(token) = self.timer_token.take() {
            self.loop_handle.remove(token);
        }
    }
}