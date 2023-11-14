use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;
use crate::flutter_engine::platform_channels::method_result::MethodResult;

type ResultHandlerSuccess<T> = Option<Box<dyn FnMut(Option<&T>)>>;

type ResultHandlerError<T> = Option<Box<dyn FnMut(&str, &str, Option<&T>)>>;

type ResultHandlerNotImplemented = Option<Box<dyn FnMut()>>;

pub struct MethodResultFunctions<T = EncodableValue> {
    on_success: ResultHandlerSuccess<T>,
    on_error: ResultHandlerError<T>,
    on_not_implemented: ResultHandlerNotImplemented,
}

impl<T> MethodResultFunctions<T> {
    pub fn new(
        on_success: ResultHandlerSuccess<T>,
        on_error: ResultHandlerError<T>,
        on_not_implemented: ResultHandlerNotImplemented,
    ) -> Self {
        Self {
            on_success,
            on_error,
            on_not_implemented,
        }
    }
}

impl<T> MethodResult<T> for MethodResultFunctions<T> {
    fn success_internal(&mut self, result: Option<T>) {
        if let Some(on_success) = self.on_success.as_mut() {
            on_success(result.as_ref());
        }
    }

    fn error_internal(&mut self, code: String, message: String, details: Option<T>) {
        if let Some(on_error) = self.on_error.as_mut() {
            on_error(code.as_str(), message.as_str(), details.as_ref());
        }
    }

    fn not_implemented_internal(&mut self) {
        if let Some(on_not_implemented) = self.on_not_implemented.as_mut() {
            on_not_implemented();
        }
    }
}
