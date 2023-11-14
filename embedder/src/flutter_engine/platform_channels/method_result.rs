use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;

pub trait MethodResult<T = EncodableValue> {
    fn success(&mut self, result: Option<T>) {
        self.success_internal(result);
    }

    fn error(&mut self, code: String, message: String, details: Option<T>) {
        self.error_internal(code, message, details);
    }

    fn not_implemented(&mut self) {
        self.not_implemented_internal();
    }

    fn success_internal(&mut self, result: Option<T>);

    fn error_internal(&mut self, code: String, message: String, details: Option<T>);

    fn not_implemented_internal(&mut self);
}
