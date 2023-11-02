use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;

#[derive(Debug)]
pub struct MethodCall<T = EncodableValue> {
    method: String,
    arguments: Option<Box<T>>,
}

impl<T> MethodCall<T> {
    pub(crate) fn new(method: String, arguments: Option<Box<T>>) -> Self {
        Self {
            method,
            arguments,
        }
    }

    pub fn method(&self) -> &str {
        &self.method
    }

    pub fn arguments(&self) -> Option<&T> {
        self.arguments.as_deref()
    }
}
