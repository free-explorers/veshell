use std::collections::HashMap;
use std::ffi::{c_void, CString};
use std::mem::size_of;
use std::ptr::{null, null_mut};

use crate::flutter_engine::embedder::{FlutterDataCallback, FlutterEngine as FlutterEngineHandle, FlutterEngineResult_kSuccess, FlutterEngineSendPlatformMessage, FlutterEngineSendPlatformMessageResponse, FlutterPlatformMessage, FlutterPlatformMessageCreateResponseHandle, FlutterPlatformMessageReleaseResponseHandle};
use crate::flutter_engine::platform_channels::binary_messenger::{BinaryMessageHandler, BinaryMessenger, BinaryReply};

pub struct BinaryMessengerImpl {
    flutter_engine: FlutterEngineHandle,
    handlers: HashMap<String, BinaryMessageHandler>,
}

impl BinaryMessengerImpl {
    pub fn new(flutter_engine: FlutterEngineHandle) -> Self {
        Self {
            flutter_engine,
            handlers: HashMap::new(),
        }
    }
}

struct Captures {
    reply: BinaryReply,
}

extern "C" fn message_reply(data: *const u8, data_size: usize, user_data: *mut ::std::os::raw::c_void) {
    let captures = unsafe { Box::from_raw(user_data as *mut Captures) };
    let data = unsafe { std::slice::from_raw_parts(data, data_size) };
    captures.reply.unwrap()(Some(data));
}

impl BinaryMessenger for BinaryMessengerImpl {

    fn handle_message(&mut self, message: &FlutterPlatformMessage) {
        let channel = unsafe { std::ffi::CStr::from_ptr(message.channel) };
        let channel = channel.to_str().unwrap();
        if let Some(handler) = self.handlers.get_mut(channel) {
            let message_bytes = unsafe { std::slice::from_raw_parts(message.message, message.message_size) };

            let response_handle = message.response_handle;
            let engine_handle = self.flutter_engine;
            let reply_handler: BinaryReply = Some(Box::new(move |reply: Option<&[u8]>| {
                let data = reply.map(|v| v.as_ptr()).unwrap_or(null());
                let data_size = reply.map(|v| v.len()).unwrap_or(0);
                unsafe { FlutterEngineSendPlatformMessageResponse(engine_handle, response_handle, data, data_size) };
            }));
            handler.as_mut().unwrap()(message_bytes, reply_handler);
        } else {
            unsafe { FlutterEngineSendPlatformMessageResponse(self.flutter_engine, message.response_handle, null(), 0) };
        }
    }

    fn send(&mut self, channel: &str, message: &[u8], reply: BinaryReply) {
        if reply.is_some() {
            let captures = Box::into_raw(Box::new(Captures {
                reply,
            }));
            let result = send_message_with_reply(self.flutter_engine, channel, message, Some(message_reply), captures as *mut c_void);
            if !result {
                let _ = unsafe { Box::from_raw(captures) };
            }
        } else {
            send_message_with_reply(self.flutter_engine, channel, message, None, null_mut());
        };
    }

    fn set_message_handler(&mut self, channel: &str, handler: BinaryMessageHandler) {
        if handler.is_some() {
            self.handlers.insert(channel.to_string(), handler);
        } else {
            self.handlers.remove(channel);
        };
    }
}

fn send_message_with_reply(flutter_engine: FlutterEngineHandle, channel: &str, message: &[u8], reply: FlutterDataCallback, user_data: *mut c_void) -> bool {
    let mut response_handle = null_mut();
    if reply.is_some() && !user_data.is_null() {
        let result = unsafe { FlutterPlatformMessageCreateResponseHandle(flutter_engine, reply, user_data, &mut response_handle) };
        if result != FlutterEngineResult_kSuccess {
            eprintln!("Failed to create response handle");
            return false;
        }
    }

    let channel_cstring = CString::new(channel).unwrap();
    let platform_message = FlutterPlatformMessage {
        struct_size: size_of::<FlutterPlatformMessage>(),
        channel: channel_cstring.as_ptr(),
        message: message.as_ptr(),
        message_size: message.len(),
        response_handle,
    };

    let message_result = unsafe { FlutterEngineSendPlatformMessage(flutter_engine, &platform_message) };
    if !response_handle.is_null() {
        unsafe { FlutterPlatformMessageReleaseResponseHandle(flutter_engine, response_handle) };
    }
    message_result == FlutterEngineResult_kSuccess
}
