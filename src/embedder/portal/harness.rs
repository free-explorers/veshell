//! Integrated D-Bus harness: private session bus, fake frontend exercising
//! the portal contract, backend calls completed through the calloop
//! bridged receiver against the REAL state machine. Covers M2.0/M2.1.

use std::collections::HashMap;
use std::process::{Child, Command};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use smithay::reexports::calloop;
use zbus::zvariant::{ObjectPath, OwnedObjectPath, OwnedValue};

use super::service::{FrontendOwner, PortalAction, PortalLedger};
use super::{
    CallReceiver, PortalCall, BACKEND_NAME, DESKTOP_PATH, FRONTEND_NAME, REQUEST_SESSION_VERSION,
    RESPONSE_FAILED, RESPONSE_OK, SCREENCAST_INTERFACE, SESSION_INTERFACE,
};

struct BusGuard {
    daemon: Child,
}

impl Drop for BusGuard {
    fn drop(&mut self) {
        let _ = self.daemon.kill();
        let _ = self.daemon.wait();
    }
}

fn start_private_session_bus() -> (BusGuard, String) {
    // Tests run in parallel inside one process: every bus gets its own
    // directory and socket.
    let unique = super::HARNESS_TEST_COUNTER.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
    let directory = std::env::temp_dir().join(format!(
        "veshell-portal-test-{}-{unique}",
        std::process::id()
    ));
    let _ = std::fs::remove_dir_all(&directory);
    std::fs::create_dir_all(&directory).expect("unique runtime dir");
    let socket = directory.join("bus");
    let address = format!("unix:path={}", socket.display());
    let daemon = Command::new("dbus-daemon")
        .arg("--session")
        .arg(format!("--address={address}"))
        .arg("--print-address")
        .arg("--nopidfile")
        .stdin(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn()
        .expect("dbus-daemon on PATH");
    for _ in 0..100 {
        if socket.exists() {
            break;
        }
        std::thread::sleep(Duration::from_millis(20));
    }
    assert!(socket.exists(), "dbus-daemon did not create {socket:?}");
    (BusGuard { daemon }, address)
}

const TEST_HANDLE: &str = "/org/freedesktop/portal/desktop/request/frontend_s1/handle1";
const TEST_SESSION: &str = "/org/freedesktop/portal/desktop/session/frontend_s1/session1";

fn portal_dict(entries: &[(&'static str, u32)]) -> HashMap<String, OwnedValue> {
    entries
        .iter()
        .map(|(key, value)| (key.to_string(), OwnedValue::from(*value)))
        .collect()
}

async fn perform_bridge_action(
    connection: &zbus::Connection,
    calls: calloop::channel::Sender<PortalCall>,
    action: PortalAction,
) -> zbus::Result<()> {
    let object_server = connection.object_server();
    match action {
        PortalAction::ExportSession(session_handle) => {
            object_server
                .at(
                    session_handle.as_str(),
                    super::SessionBackend::new(calls.clone()),
                )
                .await?;
        }
        PortalAction::ExportRequest(handle) => {
            object_server
                .at(handle.as_str(), super::RequestBackend::new(calls.clone()))
                .await
                .ok();
        }
        PortalAction::CloseSession(session_handle) => {
            connection
                .emit_signal(
                    Option::<zbus::names::BusName>::None,
                    session_handle.as_str(),
                    SESSION_INTERFACE,
                    "Closed",
                    &(),
                )
                .await
                .expect("close signal");
        }
        PortalAction::UnexportSession(session_handle) => {
            object_server
                .remove::<super::SessionBackend, _>(session_handle.as_str())
                .await
                .ok();
        }
        PortalAction::UnexportRequest(handle) => {
            object_server
                .remove::<super::RequestBackend, _>(handle.as_str())
                .await
                .ok();
        }
    }
    Ok(())
}

/// The loop-side consumer: the same shape the M2.1 `State` handler takes,
/// here driving the REAL ledger plus the object bridge.
fn drain_portal_calls(
    service: zbus::Connection,
    test_calls: calloop::channel::Sender<PortalCall>,
    receiver: CallReceiver,
    ledger: Arc<Mutex<PortalLedger>>,
    running: Arc<AtomicBool>,
) -> std::thread::JoinHandle<()> {
    std::thread::spawn(move || {
        let mut event_loop = smithay::reexports::calloop::EventLoop::<()>::try_new().unwrap();
        event_loop
            .handle()
            .insert_source(receiver, |event, _metadata, (): &mut ()| match event {
                smithay::reexports::calloop::channel::Event::Msg(call) => {
                    let mut actions = Vec::new();
                    {
                        let mut ledger = ledger.lock().unwrap();
                        super::service::apply_portal_call(&mut ledger, call, &mut actions);
                    }
                    for action in actions {
                        if let Err(error) = zbus::block_on(perform_bridge_action(
                            &service,
                            test_calls.clone(),
                            action,
                        )) {
                            println!("DEBUG bridge action error: {error:?}");
                        }
                    }
                }
                smithay::reexports::calloop::channel::Event::Closed => (),
            })
            .expect("portal bridge source");
        while running.load(Ordering::SeqCst) {
            event_loop
                .dispatch(Some(Duration::from_millis(5)), &mut ())
                .expect("portal bridge dispatch");
        }
    })
}

fn screen_cast_call(
    connection: &zbus::blocking::Connection,
    method: &'static str,
    handle: &'static str,
    session: &'static str,
    app: &'static str,
    options: HashMap<String, OwnedValue>,
) -> (u32, HashMap<String, OwnedValue>) {
    let message = connection
        .call_method(
            Some(BACKEND_NAME),
            DESKTOP_PATH,
            Some(SCREENCAST_INTERFACE),
            method,
            &(
                OwnedObjectPath::try_from(handle).expect("test handle"),
                OwnedObjectPath::try_from(session).expect("test session handle"),
                app,
                options,
            ),
        )
        .expect("backend call must resolve");
    message
        .body()
        .deserialize::<(u32, HashMap<String, OwnedValue>)>()
        .expect("backend response body")
}

/// The service continues to reject callers that are not the frontend
/// (whatever their app_id), and the fake frontend cannot bypass it either
/// with a well-known name of its own.
#[test]
fn backend_serves_frontend_through_the_loop() {
    let (bus_guard, address) = start_private_session_bus();

    let running = Arc::new(AtomicBool::new(true));
    let (service, calls_for_bridge, call_receiver) =
        zbus::block_on(super::build_backend_connection(&address)).expect("backend connection");

    let frontend = zbus::blocking::connection::Builder::address(address.as_str())
        .expect("frontend builder")
        .name(FRONTEND_NAME)
        .expect("frontend name")
        .build()
        .expect("frontend connection");
    let frontend_owner = zbus::blocking::fdo::DBusProxy::new(&frontend)
        .expect("driver proxy")
        .get_name_owner(zbus::names::BusName::try_from(FRONTEND_NAME).expect("well-known name"))
        .expect("frontend owner probe");
    let ledger = Arc::new(Mutex::new(PortalLedger {
        frontend: Some(FrontendOwner(frontend_owner.to_string())),
        ..Default::default()
    }));

    let consumer = drain_portal_calls(
        service.clone(),
        calls_for_bridge.clone(),
        call_receiver,
        ledger.clone(),
        running.clone(),
    );

    let (response, results) = screen_cast_call(
        &frontend,
        "CreateSession",
        TEST_HANDLE,
        TEST_SESSION,
        "app",
        Default::default(),
    );
    assert_eq!(response, RESPONSE_OK);
    assert!(results.is_empty());

    // Session object contract: version property served on the session path.
    zbus::block_on(async {
        let properties = zbus::fdo::PropertiesProxy::builder(&service)
            .destination(BACKEND_NAME)
            .expect("destination")
            .path(TEST_SESSION)
            .expect("test session path")
            .build()
            .await
            .expect("session properties proxy");
        // The export happens asynchronously on the consumer thread; giving
        // the bridge a bounded grace to converge is part of the harness, not
        // of the contract.
        let mut version: Option<u32> = None;
        for _ in 0..50 {
            match properties
                .get(
                    zbus::names::InterfaceName::try_from(SESSION_INTERFACE).expect("session iface"),
                    "version",
                )
                .await
            {
                Ok(value) => {
                    version = Some(value.try_into().expect("u32"));
                    break;
                }
                Err(_) => {
                    std::thread::sleep(std::time::Duration::from_millis(5));
                }
            }
        }
        assert_eq!(version, Some(REQUEST_SESSION_VERSION));
    });

    let (response, _results) = screen_cast_call(
        &frontend,
        "SelectSources",
        TEST_HANDLE,
        TEST_SESSION,
        "app",
        portal_dict(&[("types", 1), ("cursor_mode", 2)]),
    );
    assert_eq!(response, RESPONSE_OK);
    let session_path = OwnedObjectPath::try_from(TEST_SESSION).unwrap();
    let session = ledger
        .lock()
        .unwrap()
        .sessions
        .get(&session_path)
        .cloned()
        .unwrap();
    assert_eq!(session.state, super::service::SessionState::Configured);
    assert_eq!(
        session.constraints.expect("stored constraints").cursor_mode,
        super::CursorModes::from_bits(2).unwrap()
    );

    // VIRTUAL-only request is rejected as response 2 by validation.
    let (response, _results) = screen_cast_call(
        &frontend,
        "SelectSources",
        TEST_HANDLE,
        TEST_SESSION,
        "app",
        portal_dict(&[("types", 4)]),
    );
    assert_eq!(response, RESPONSE_FAILED);

    running.store(false, Ordering::SeqCst);
    consumer.join().expect("consumer thread");
    drop(service);
    drop(bus_guard);
}

/// A second bus client without the frontend name cannot create sessions.
#[test]
fn backend_rejects_unauthenticated_callers() {
    let (bus_guard, address) = start_private_session_bus();

    let running = Arc::new(AtomicBool::new(true));
    let (service, calls_for_bridge, call_receiver) =
        zbus::block_on(super::build_backend_connection(&address)).expect("backend connection");

    let frontend = zbus::blocking::connection::Builder::address(address.as_str())
        .expect("frontend builder")
        .name(FRONTEND_NAME)
        .expect("frontend name")
        .build()
        .expect("frontend connection");
    let frontend_owner = zbus::blocking::fdo::DBusProxy::new(&frontend)
        .expect("driver proxy")
        .get_name_owner(zbus::names::BusName::try_from(FRONTEND_NAME).expect("well-known name"))
        .expect("frontend owner probe");
    let ledger = Arc::new(Mutex::new(PortalLedger {
        frontend: Some(FrontendOwner(frontend_owner.to_string())),
        ..Default::default()
    }));
    let consumer = drain_portal_calls(
        service.clone(),
        calls_for_bridge.clone(),
        call_receiver,
        ledger.clone(),
        running.clone(),
    );

    // An imposter bus client (no frontend name).
    let imposter = zbus::blocking::connection::Builder::address(address.as_str())
        .expect("imposter builder")
        .build()
        .expect("imposter connection");
    let (response, _results) = screen_cast_call(
        &imposter,
        "CreateSession",
        TEST_HANDLE,
        TEST_SESSION,
        "app",
        Default::default(),
    );
    assert_eq!(response, RESPONSE_FAILED);
    assert!(ledger.lock().unwrap().sessions.is_empty());

    running.store(false, Ordering::SeqCst);
    consumer.join().expect("consumer thread");
    drop(service);
    drop(bus_guard);
}
