use std::cell::RefCell;
use std::rc::Rc;

use crate::flutter_engine::platform_channels::binary_messenger::{BinaryMessenger, BinaryReply};
use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;
use crate::flutter_engine::platform_channels::message_codec::MessageCodec;

pub struct BasicMessageChannel<T = EncodableValue> {
    messenger: Rc<RefCell<dyn BinaryMessenger>>,
    name: String,
    codec: Rc<dyn MessageCodec<T>>,
}

impl<T: 'static> BasicMessageChannel<T> {
    pub fn new(
        messenger: Rc<RefCell<dyn BinaryMessenger>>,
        name: String,
        codec: Rc<dyn MessageCodec<T>>,
    ) -> Self {
        Self {
            messenger,
            name,
            codec,
        }
    }

    pub fn send(&self, message: &T, reply: BinaryReply) {
        let message = self.codec.encode_message(message);
        self.messenger
            .borrow_mut()
            .send(&self.name, &message, reply);
    }
}
