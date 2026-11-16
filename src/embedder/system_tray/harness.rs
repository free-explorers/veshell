//! Private-bus integration test for the watcher: items registered by bus name
//! and by object path are listed and forwarded, and leave once their bus name
//! loses its owner.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use smithay::reexports::calloop;

use super::{
    spawn_watcher, EventReceiver, SystemTrayEvent, DEFAULT_ITEM_PATH, WATCHER_INTERFACE,
    WATCHER_NAME, WATCHER_PATH,
};

/// Collects the forwarded events, standing in for the compositor loop.
fn collect_events(
    receiver: EventReceiver,
    running: Arc<AtomicBool>,
) -> (
    Arc<Mutex<Vec<SystemTrayEvent>>>,
    std::thread::JoinHandle<()>,
) {
    let events = Arc::new(Mutex::new(Vec::new()));
    let collected = events.clone();
    let thread = std::thread::spawn(move || {
        let mut event_loop = calloop::EventLoop::<()>::try_new().unwrap();
        event_loop
            .handle()
            .insert_source(receiver, move |event, _, (): &mut ()| {
                if let calloop::channel::Event::Msg(event) = event {
                    collected.lock().unwrap().push(event);
                }
            })
            .expect("system tray bridge source");
        while running.load(Ordering::SeqCst) {
            event_loop
                .dispatch(Some(Duration::from_millis(5)), &mut ())
                .expect("system tray bridge dispatch");
        }
    });
    (events, thread)
}

fn wait_for(events: &Mutex<Vec<SystemTrayEvent>>, expected: &SystemTrayEvent) {
    let deadline = Instant::now() + Duration::from_secs(5);
    while Instant::now() < deadline {
        if events.lock().unwrap().iter().any(|event| event == expected) {
            return;
        }
        std::thread::sleep(Duration::from_millis(10));
    }
    panic!(
        "missing {expected:?}, got {:?}",
        events.lock().unwrap().as_slice()
    );
}

fn registered_items(client: &zbus::blocking::Connection) -> Vec<String> {
    let proxy = zbus::blocking::Proxy::new(client, WATCHER_NAME, WATCHER_PATH, WATCHER_INTERFACE)
        .expect("watcher proxy");
    proxy
        .get_property("RegisteredStatusNotifierItems")
        .expect("RegisteredStatusNotifierItems")
}

fn register(client: &zbus::blocking::Connection, service: &str) {
    client
        .call_method(
            Some(WATCHER_NAME),
            WATCHER_PATH,
            Some(WATCHER_INTERFACE),
            "RegisterStatusNotifierItem",
            &(service,),
        )
        .expect("RegisterStatusNotifierItem");
}

#[test]
fn watcher_tracks_items_until_their_name_goes() {
    let (bus_guard, address) = crate::portal::harness::start_private_session_bus();
    let receiver = spawn_watcher(Some(address.clone())).expect("watcher");
    let running = Arc::new(AtomicBool::new(true));
    let (events, consumer) = collect_events(receiver, running.clone());

    let connect = || {
        zbus::blocking::connection::Builder::address(address.as_str())
            .expect("client builder")
            .build()
            .expect("client connection")
    };

    // The shell is the host from the start.
    let observer = connect();
    let proxy =
        zbus::blocking::Proxy::new(&observer, WATCHER_NAME, WATCHER_PATH, WATCHER_INTERFACE)
            .expect("watcher proxy");
    let host: bool = proxy
        .get_property("IsStatusNotifierHostRegistered")
        .expect("IsStatusNotifierHostRegistered");
    assert!(host);

    // A KDE-style item: registered by the well-known name it owns.
    let named = connect();
    let item_name = "org.kde.StatusNotifierItem-1-1";
    named.request_name(item_name).expect("item name");
    register(&named, item_name);
    let named_id = format!("{item_name}{DEFAULT_ITEM_PATH}");
    let pid = Some(std::process::id() as i32);
    wait_for(
        &events,
        &SystemTrayEvent::ItemRegistered(super::TrayItem {
            id: named_id.clone(),
            bus_name: item_name.to_string(),
            object_path: DEFAULT_ITEM_PATH.to_string(),
            pid,
        }),
    );

    // An Ayatana-style item: registered by object path on its own connection.
    let by_path = connect();
    let unique = by_path.unique_name().expect("unique name").to_string();
    register(&by_path, "/org/ayatana/NotificationItem/app");
    let path_id = format!("{unique}/org/ayatana/NotificationItem/app");
    wait_for(
        &events,
        &SystemTrayEvent::ItemRegistered(super::TrayItem {
            id: path_id.clone(),
            bus_name: unique,
            object_path: "/org/ayatana/NotificationItem/app".to_string(),
            pid,
        }),
    );

    // Registering again changes nothing.
    register(&named, item_name);
    assert_eq!(
        registered_items(&observer),
        vec![named_id.clone(), path_id.clone()]
    );

    // Hiding an item releases its name while the application stays connected.
    named.release_name(item_name).expect("release item name");
    wait_for(
        &events,
        &SystemTrayEvent::ItemUnregistered {
            id: named_id.clone(),
        },
    );

    // Quitting drops the connection, and its unique name with it.
    drop(by_path);
    wait_for(
        &events,
        &SystemTrayEvent::ItemUnregistered {
            id: path_id.clone(),
        },
    );
    assert!(registered_items(&observer).is_empty());

    // Each item was forwarded exactly once each way.
    let registered = events
        .lock()
        .unwrap()
        .iter()
        .filter(|event| matches!(event, SystemTrayEvent::ItemRegistered(_)))
        .count();
    assert_eq!(registered, 2);

    running.store(false, Ordering::SeqCst);
    consumer.join().expect("consumer thread");
    drop(named);
    drop(observer);
    drop(bus_guard);
}
