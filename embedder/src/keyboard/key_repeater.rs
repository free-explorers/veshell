use crate::backend::Backend;
use crate::state::State;
use smithay::reexports::calloop::timer::{TimeoutAction, Timer};
use smithay::reexports::calloop::{LoopHandle, RegistrationToken};
use std::time::Duration;

type Callback<BackendData> = fn(u32, Option<char>, &mut State<BackendData>);

pub struct KeyRepeater<BackendData: Backend + 'static> {
    loop_handle: LoopHandle<'static, State<BackendData>>,
    timer_token: Option<RegistrationToken>,
    callback: Callback<BackendData>,
    repeating_key: Option<u32>,
}

impl<BackendData: Backend + 'static> KeyRepeater<BackendData> {
    pub fn new(
        loop_handle: LoopHandle<'static, State<BackendData>>,
        callback: Callback<BackendData>,
    ) -> Self {
        Self {
            loop_handle,
            timer_token: None,
            callback,
            repeating_key: None,
        }
    }

    pub fn down(
        &mut self,
        key_code: u32,
        char_point: Option<char>,
        repeat_delay: Duration,
        repeat_rate: Duration,
    ) {
        // Cancel any existing key repeat, we don't want to repeat multiple keys at once.
        self.cancel();
        self.repeating_key = Some(key_code);

        let timer = Timer::from_duration(repeat_delay);

        let callback = self.callback.clone();
        let token = self
            .loop_handle
            .insert_source(timer, move |_, _, data| {
                callback(key_code, char_point, data);
                // Reschedule the timer over and over.
                TimeoutAction::ToDuration(repeat_rate)
            })
            .unwrap();

        self.timer_token = Some(token);
    }

    pub fn up(&mut self, key_code: u32) {
        let repeating_key = match self.repeating_key {
            Some(repeating_key) => repeating_key,
            None => return,
        };
        // Only stop the key repeat if the user releases the same key that caused the repeat.
        if repeating_key == key_code {
            self.cancel();
        }
    }

    fn cancel(&mut self) {
        if let Some(token) = self.timer_token.take() {
            self.loop_handle.remove(token);
        }
    }
}
