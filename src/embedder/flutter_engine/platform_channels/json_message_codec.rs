use crate::flutter_engine::platform_channels::message_codec::MessageCodec;

#[derive(Default)]
pub struct JsonMessageCodec {}

impl JsonMessageCodec {
    pub fn new() -> Self {
        Default::default()
    }
}

impl MessageCodec<serde_json::Value> for JsonMessageCodec {
    fn decode_message_internal(&self, message: &[u8]) -> Option<serde_json::Value> {
        serde_json::from_slice(message).ok()
    }

    fn encode_message_internal(&self, message: &serde_json::Value) -> Vec<u8> {
        serde_json::to_vec(message).unwrap()
    }
}
