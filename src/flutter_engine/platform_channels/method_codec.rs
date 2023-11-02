use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;

pub trait MethodCodec<T> {
    fn decode_method_call(&self, message: &[u8]) -> Option<MethodCall<T>> {
        self.decode_method_call_internal(message)
    }

    fn decode_method_call_vec(&self, message: Vec<u8>) -> Option<MethodCall<T>> {
        self.decode_method_call_internal(&message)
    }

    fn encode_method_call(&self, method_call: &MethodCall<T>) -> Vec<u8> {
        self.encode_method_call_internal(method_call)
    }

    fn encode_success_envelope(&self, result: Option<&T>) -> Vec<u8> {
        self.encode_success_envelope_internal(result)
    }

    fn encode_error_envelope(&self, code: &str, message: &str, details: Option<&T>) -> Vec<u8> {
        self.encode_error_envelope_internal(code, message, details)
    }

    fn decode_and_process_response_envelope(&self, response: &[u8], result: &mut dyn MethodResult<T>) -> bool {
        self.decode_and_process_response_envelope_internal(response, result)
    }

    fn decode_method_call_internal(&self, message: &[u8]) -> Option<MethodCall<T>>;

    fn encode_method_call_internal(&self, method_call: &MethodCall<T>) -> Vec<u8>;

    fn encode_success_envelope_internal(&self, result: Option<&T>) -> Vec<u8>;

    fn encode_error_envelope_internal(&self, code: &str, message: &str, details: Option<&T>) -> Vec<u8>;

    fn decode_and_process_response_envelope_internal(&self, response: &[u8], result: &mut dyn MethodResult<T>) -> bool;
}
