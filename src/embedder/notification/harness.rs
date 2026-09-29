//! Private-bus integration test for the notification transport skeleton:
//! the served interface answers the protocol methods, and `Notify` is
//! completed through the loop-side reply seam.

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use smithay::reexports::calloop;
use zbus::zvariant::OwnedValue;

use super::{
    CallReceiver, NotificationCall, CAPABILITIES, NOTIFICATION_INTERFACE, NOTIFICATION_NAME,
    NOTIFICATION_PATH,
};

/// The loop-side consumer: answers every `Notify` with id 1, standing in for
/// the shell until the forwarding slice lands.
fn drain_notification_calls(
    receiver: CallReceiver,
    running: Arc<AtomicBool>,
) -> std::thread::JoinHandle<()> {
    std::thread::spawn(move || {
        let mut event_loop = calloop::EventLoop::<()>::try_new().unwrap();
        event_loop
            .handle()
            .insert_source(receiver, |event, _, (): &mut ()| match event {
                calloop::channel::Event::Msg(call) => match call {
                    NotificationCall::Notify { reply, .. } => reply.send(1),
                    NotificationCall::CloseNotification { .. } => {}
                },
                calloop::channel::Event::Closed => {}
            })
            .expect("notification bridge source");
        while running.load(Ordering::SeqCst) {
            event_loop
                .dispatch(Some(Duration::from_millis(5)), &mut ())
                .expect("notification bridge dispatch");
        }
    })
}

#[test]
fn notification_interface_serves_protocol_calls() {
    let (bus_guard, address) = crate::portal::harness::start_private_session_bus();

    let (service, receiver) =
        zbus::block_on(super::build_notification_connection(&address)).expect("server connection");
    let running = Arc::new(AtomicBool::new(true));
    let consumer = drain_notification_calls(receiver, running.clone());

    let client = zbus::blocking::connection::Builder::address(address.as_str())
        .expect("client builder")
        .build()
        .expect("client connection");

    // Static metadata is answered without the loop.
    let reply = client
        .call_method(
            Some(NOTIFICATION_NAME),
            NOTIFICATION_PATH,
            Some(NOTIFICATION_INTERFACE),
            "GetCapabilities",
            &(),
        )
        .expect("GetCapabilities");
    let capabilities: Vec<String> = reply.body().deserialize().expect("capabilities body");
    assert_eq!(
        capabilities,
        CAPABILITIES
            .iter()
            .map(|capability| capability.to_string())
            .collect::<Vec<_>>()
    );

    let reply = client
        .call_method(
            Some(NOTIFICATION_NAME),
            NOTIFICATION_PATH,
            Some(NOTIFICATION_INTERFACE),
            "GetServerInformation",
            &(),
        )
        .expect("GetServerInformation");
    let information: (String, String, String, String) =
        reply.body().deserialize().expect("information body");
    assert_eq!(information.0, "VeshellNotificationServer");

    // `Notify` is completed by the loop-side reply seam.
    let reply = client
        .call_method(
            Some(NOTIFICATION_NAME),
            NOTIFICATION_PATH,
            Some(NOTIFICATION_INTERFACE),
            "Notify",
            &(
                "app",
                0u32,
                "",
                "summary",
                "body",
                Vec::<String>::new(),
                HashMap::<String, OwnedValue>::new(),
                -1i32,
            ),
        )
        .expect("Notify");
    let id: u32 = reply.body().deserialize().expect("notify body");
    assert_eq!(id, 1);

    // `CloseNotification` is accepted without a reply body.
    client
        .call_method(
            Some(NOTIFICATION_NAME),
            NOTIFICATION_PATH,
            Some(NOTIFICATION_INTERFACE),
            "CloseNotification",
            &(1u32,),
        )
        .expect("CloseNotification");

    running.store(false, Ordering::SeqCst);
    consumer.join().expect("consumer thread");
    drop(service);
    drop(client);
    drop(bus_guard);
}
