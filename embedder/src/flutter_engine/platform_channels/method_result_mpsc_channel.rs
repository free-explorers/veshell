//! This file was not translated from C++ from the Flutter engine repo.
//! It's an alternative for MethodResultFunctions that adds the result into an mpsc channel
//! instead of storing closures.
//! This way, it can be used with the Calloop event loop and access external state without having
//! to capture the state inside closures.

use smithay::reexports::calloop::channel;

use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;
use crate::flutter_engine::platform_channels::method_result::MethodResult;

pub enum MethodResultEnum<T> {
    Success(Option<T>),
    Error {
        code: String,
        message: String,
        details: Option<T>,
    },
    NotImplemented,
}

pub struct MethodResultMpscChannel<T = EncodableValue> {
    tx_channel: channel::Sender<MethodResultEnum<T>>,
}

impl<T> MethodResultMpscChannel<T> {
    pub fn new(tx_channel: channel::Sender<MethodResultEnum<T>>) -> Self {
        Self {
            tx_channel,
        }
    }
}

impl<T> MethodResult<T> for MethodResultMpscChannel<T> {
    fn success_internal(&mut self, result: Option<T>) {
        let _ = self.tx_channel.send(MethodResultEnum::Success(result));
    }

    fn error_internal(&mut self, code: String, message: String, details: Option<T>) {
        let _ = self.tx_channel.send(MethodResultEnum::Error {
            code,
            message,
            details,
        });
    }

    fn not_implemented_internal(&mut self) {
        let _ = self.tx_channel.send(MethodResultEnum::NotImplemented);
    }
}
