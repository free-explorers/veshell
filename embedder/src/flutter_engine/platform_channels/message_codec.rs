pub trait MessageCodec<T> {
    fn decode_message(&self, message: &[u8]) -> Option<T> {
        self.decode_message_internal(message)
    }

    fn decode_message_vec(&self, message: Vec<u8>) -> Option<T> {
        self.decode_message_internal(&message)
    }
    fn encode_message(&self, message: &T) -> Vec<u8> {
        self.encode_message_internal(message)
    }
    fn decode_message_internal(&self, message: &[u8]) -> Option<T>;
    fn encode_message_internal(&self, message: &T) -> Vec<u8>;
}
