use std::cell::RefCell;
use std::rc::Rc;

use crate::flutter_engine::platform_channels::binary_messenger::{BinaryMessageHandler, BinaryMessenger, BinaryReply};
use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;
use crate::flutter_engine::platform_channels::message_codec::MessageCodec;

type MessageReply<T> = Option<Box<dyn FnMut(Option<T>)>>;

type MessageHandler<T> = Option<Box<dyn FnMut(Option<T>, MessageReply<T>)>>;

pub struct BasicMessageChannel<T = EncodableValue> {
    messenger: Rc<RefCell<dyn BinaryMessenger>>,
    name: String,
    codec: Rc<dyn MessageCodec<T>>,
}

impl<T: 'static> BasicMessageChannel<T> {
    pub fn new(messenger: Rc<RefCell<dyn BinaryMessenger>>, name: String, codec: Rc<dyn MessageCodec<T>>) -> Self {
        Self {
            messenger,
            name,
            codec,
        }
    }

    pub fn send(&self, message: &T, reply: BinaryReply) {
        let message = self.codec.encode_message(message);
        self.messenger.borrow_mut().send(&self.name, &message, reply);
    }

    pub fn set_message_handler(&mut self, handler: MessageHandler<T>) {
        let mut handler = if let Some(handler) = handler {
            handler
        } else {
            self.messenger.borrow_mut().set_message_handler(&self.name, None);
            return;
        };

        let codec = self.codec.clone();
        let channel_name = self.name.clone();

        let binary_handler: BinaryMessageHandler = Some(Box::new(move |message: &[u8], reply: BinaryReply| {
            let message = codec.decode_message(message);
            let message = if let Some(message) = message {
                message
            } else {
                eprintln!("Unable to decode message on channel {}", channel_name);
                reply.unwrap()(None);
                return;
            };

            let unencoded_reply: MessageReply<T> = Some(Box::new(move |response: Option<T>| {
                let response = codec.encode_message(&response.unwrap());
                reply.unwrap()(Some(&response));
            }));

            handler(Some(message), unencoded_reply);
        }));

        self.messenger.borrow_mut().set_message_handler(&channel_name, binary_handler);
    }
}