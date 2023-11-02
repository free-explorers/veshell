use crate::flutter_engine::platform_channels::byte_buffer_streams::{ByteBufferStreamReader, ByteBufferStreamWriter};
use crate::flutter_engine::platform_channels::byte_streams::{ByteStreamReader, ByteStreamWriter};
use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_codec::MethodCodec;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::flutter_engine::platform_channels::standard_codec_serializer::StandardCodecSerializer;

#[derive(Default, Copy, Clone)]
pub struct StandardMethodCodec {
    serializer: StandardCodecSerializer,
}

impl StandardMethodCodec {
    pub fn new() -> Self {
        Default::default()
    }
}

impl MethodCodec<EncodableValue> for StandardMethodCodec {
    fn decode_method_call_internal(&self, message: &[u8]) -> Option<MethodCall<EncodableValue>> {
        let mut stream = ByteBufferStreamReader::new(message);
        let method_name = self.serializer.read_value(&mut stream);
        if let EncodableValue::String(method_name) = method_name {
            let arguments = self.serializer.read_value(&mut stream);
            Some(MethodCall::new(method_name, Some(Box::new(arguments))))
        } else {
            eprintln!("Invalid method call; method name is not a string.");
            None
        }
    }

    fn encode_method_call_internal(&self, method_call: &MethodCall<EncodableValue>) -> Vec<u8> {
        let mut encoded = Vec::new();
        let mut stream = ByteBufferStreamWriter::new(&mut encoded);
        self.serializer.write_value(&EncodableValue::String(method_call.method().to_string()), &mut stream);
        if let Some(arguments) = method_call.arguments() {
            self.serializer.write_value(arguments, &mut stream);
        } else {
            self.serializer.write_value(&EncodableValue::Null, &mut stream);
        }
        encoded
    }

    fn encode_success_envelope_internal(&self, result: Option<&EncodableValue>) -> Vec<u8> {
        let mut encoded = Vec::new();
        let mut stream = ByteBufferStreamWriter::new(&mut encoded);
        stream.write_byte(0);
        if let Some(result) = result {
            self.serializer.write_value(result, &mut stream);
        } else {
            self.serializer.write_value(&EncodableValue::Null, &mut stream);
        }
        encoded
    }

    fn encode_error_envelope_internal(&self, code: &str, message: &str, details: Option<&EncodableValue>) -> Vec<u8> {
        let mut encoded = Vec::new();
        let mut stream = ByteBufferStreamWriter::new(&mut encoded);
        stream.write_byte(1);
        self.serializer.write_value(&EncodableValue::String(code.to_string()), &mut stream);
        if message.is_empty() {
            self.serializer.write_value(&EncodableValue::Null, &mut stream);
        } else {
            self.serializer.write_value(&EncodableValue::String(message.to_string()), &mut stream);
        }
        if let Some(details) = details {
            self.serializer.write_value(details, &mut stream);
        } else {
            self.serializer.write_value(&EncodableValue::Null, &mut stream);
        }
        encoded
    }

    fn decode_and_process_response_envelope_internal(&self, response: &[u8], result: &mut dyn MethodResult<EncodableValue>) -> bool {
        let mut stream = ByteBufferStreamReader::new(response);
        let flag = stream.read_byte();
        if flag == 0 {
            let value = self.serializer.read_value(&mut stream);
            result.success(if let EncodableValue::Null = value {
                None
            } else {
                Some(value)
            });
            true
        } else if flag == 1 {
            let code = self.serializer.read_value(&mut stream);
            let message = self.serializer.read_value(&mut stream);
            let details = self.serializer.read_value(&mut stream);

            let code_string = match code {
                EncodableValue::String(code) => code.to_string(),
                _ => "".to_string(),
            };

            let message_string = match message {
                EncodableValue::String(message) => message.to_string(),
                _ => "".to_string(),
            };

            if let EncodableValue::Null = details {
                result.error(code_string, message_string, None);
            } else {
                result.error(code_string, message_string, Some(details));
            }
            true
        } else {
            eprintln!("Invalid error envelope; flag is not 0 or 1.");
            false
        }
    }
}
