use std::rc::Rc;

use crate::flutter_engine::platform_channels::byte_buffer_streams::{ByteBufferStreamReader, ByteBufferStreamWriter};
use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;
use crate::flutter_engine::platform_channels::message_codec::MessageCodec;
use crate::flutter_engine::platform_channels::standard_codec_serializer::StandardCodecSerializer;

#[derive(Default)]
pub struct StandardMessageCodec {
    serializer: Rc<StandardCodecSerializer>,
}

impl StandardMessageCodec {
    pub fn new() -> Self {
        Default::default()
    }
}

impl MessageCodec<EncodableValue> for StandardMessageCodec {
    fn decode_message_internal(&self, message: &[u8]) -> Option<EncodableValue> {
        if message.is_empty() {
            return Some(EncodableValue::Null);
        }
        let mut stream = ByteBufferStreamReader::new(message);
        let value = self.serializer.read_value(&mut stream);
        Some(value)
    }

    fn encode_message_internal(&self, message: &EncodableValue) -> Vec<u8> {
        let mut buffer = Vec::new();
        let mut stream = ByteBufferStreamWriter::new(&mut buffer);
        self.serializer.write_value(message, &mut stream);
        buffer
    }
}
