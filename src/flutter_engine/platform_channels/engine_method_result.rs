use std::rc::Rc;

use crate::flutter_engine::platform_channels::binary_messenger::BinaryReply;
use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;
use crate::flutter_engine::platform_channels::method_codec::MethodCodec;
use crate::flutter_engine::platform_channels::method_result::MethodResult;

struct ReplyManager {
    reply_handler: BinaryReply,
}

impl ReplyManager {
    pub fn new(reply_handler: BinaryReply) -> Self {
        Self {
            reply_handler,
        }
    }

    pub fn send_response_data(&mut self, data: Option<&Vec<u8>>) {
        let mut reply_handler = if let Some(reply_handler) = self.reply_handler.take() {
            reply_handler
        } else {
            eprintln!("Error: Only one of Success, Error, or NotImplemented can be called, \
            and it can be called exactly once. Ignoring duplicate result.");
            return;
        };

        reply_handler(data.and_then(|v| if v.is_empty() {
            None
        } else {
            Some(v.as_slice())
        }));
    }
}

impl Drop for ReplyManager {
    fn drop(&mut self) {
        if self.reply_handler.is_some() {
            eprintln!("Warning: Failed to respond to a message. This is a memory leak.");
        }
    }
}

pub struct EngineMethodResult<T = EncodableValue> {
    reply_manager: ReplyManager,
    codec: Rc<dyn MethodCodec<T>>,
}

impl<T> EngineMethodResult<T> {
    pub fn new(reply_handler: BinaryReply, codec: Rc<dyn MethodCodec<T>>) -> Self {
        Self {
            reply_manager: ReplyManager::new(reply_handler),
            codec,
        }
    }
}

impl<T> MethodResult<T> for EngineMethodResult<T> {
    fn success_internal(&mut self, result: Option<T>) {
        let data = self.codec.encode_success_envelope(result.as_ref());
        self.reply_manager.send_response_data(Some(&data));
    }

    fn error_internal(&mut self, code: String, message: String, details: Option<T>) {
        let data = self.codec.encode_error_envelope(code.as_str(), message.as_str(), details.as_ref());
        self.reply_manager.send_response_data(Some(&data));
    }

    fn not_implemented_internal(&mut self) {
        self.reply_manager.send_response_data(None)
    }
}
