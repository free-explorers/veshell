//! logind side of the lock screen.
//!
//! One thread owns the system-bus connection. It forwards the session's
//! `Lock`/`Unlock` signals and `PrepareForSleep` to the compositor loop, and
//! applies the loop's commands: publishing `LockedHint` and releasing the
//! sleep "delay" inhibitor once the lock screen is on screen. Compositor data
//! never crosses to this thread.

use futures_util::StreamExt;
use smithay::reexports::calloop::channel;
use tracing::{debug, info, warn};
use zbus::zvariant::{OwnedFd, OwnedObjectPath};
use zbus::{Connection, Proxy};

const LOGIN1_NAME: &str = "org.freedesktop.login1";
const LOGIN1_PATH: &str = "/org/freedesktop/login1";
const LOGIN1_MANAGER: &str = "org.freedesktop.login1.Manager";
const LOGIN1_SESSION: &str = "org.freedesktop.login1.Session";
const LOGIN1_USER: &str = "org.freedesktop.login1.User";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LockDbusEvent {
    /// logind asks this session to lock (`loginctl lock-session`, the power
    /// menu, another tool).
    Lock,
    /// logind asks this session to unlock (`loginctl unlock-session`).
    Unlock,
    /// The system is about to suspend: lock now, then release the inhibitor.
    PrepareForSleep,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LockDbusCommand {
    SetLockedHint(bool),
    /// The lock screen is visible: let a pending suspend proceed.
    ReleaseSleepInhibitor,
}

enum Item {
    Lock,
    Unlock,
    PrepareForSleep(bool),
    Command(LockDbusCommand),
}

pub fn spawn(events: channel::Sender<LockDbusEvent>) -> async_channel::Sender<LockDbusCommand> {
    let (commands, receiver) = async_channel::unbounded();
    std::thread::Builder::new()
        .name("lock-logind".into())
        .spawn(move || {
            if let Err(error) = zbus::block_on(run(events, receiver)) {
                warn!(?error, "logind lock watch ended");
            }
        })
        .expect("Failed to spawn the logind lock thread");
    commands
}

async fn run(
    events: channel::Sender<LockDbusEvent>,
    commands: async_channel::Receiver<LockDbusCommand>,
) -> zbus::Result<()> {
    let connection = Connection::system().await?;
    let manager = Proxy::new(&connection, LOGIN1_NAME, LOGIN1_PATH, LOGIN1_MANAGER).await?;

    let session = match resolve_session(&connection, &manager).await {
        Ok(path) => {
            info!(%path, "Lock screen follows logind session");
            Some(Proxy::new(&connection, LOGIN1_NAME, path, LOGIN1_SESSION).await?)
        }
        Err(error) => {
            warn!(
                ?error,
                "No logind session found: lock-session requests and LockedHint are disabled"
            );
            None
        }
    };

    let mut inhibitor = take_sleep_inhibitor(&manager).await;

    let sleep = manager
        .receive_signal("PrepareForSleep")
        .await?
        .filter_map(|signal| async move {
            signal
                .body()
                .deserialize::<bool>()
                .ok()
                .map(Item::PrepareForSleep)
        })
        .boxed();
    let commands = commands.map(Item::Command).boxed();
    let mut items = futures_util::stream::select(sleep, commands).boxed();
    if let Some(session) = &session {
        let lock = session.receive_signal("Lock").await?.map(|_| Item::Lock);
        let unlock = session
            .receive_signal("Unlock")
            .await?
            .map(|_| Item::Unlock);
        items =
            futures_util::stream::select(items, futures_util::stream::select(lock, unlock).boxed())
                .boxed();
    }

    while let Some(item) = items.next().await {
        let event = match item {
            Item::Lock => Some(LockDbusEvent::Lock),
            Item::Unlock => Some(LockDbusEvent::Unlock),
            Item::PrepareForSleep(true) => Some(LockDbusEvent::PrepareForSleep),
            Item::PrepareForSleep(false) => {
                // Resumed: arm the next suspend.
                if inhibitor.is_none() {
                    inhibitor = take_sleep_inhibitor(&manager).await;
                }
                None
            }
            Item::Command(LockDbusCommand::SetLockedHint(locked)) => {
                if let Some(session) = &session {
                    if let Err(error) = session.call_method("SetLockedHint", &(locked,)).await {
                        warn!(?error, "Failed to publish LockedHint");
                    }
                }
                None
            }
            Item::Command(LockDbusCommand::ReleaseSleepInhibitor) => {
                if inhibitor.take().is_some() {
                    debug!("Released the sleep inhibitor");
                }
                None
            }
        };
        if let Some(event) = event {
            if events.send(event).is_err() {
                break;
            }
        }
    }
    Ok(())
}

/// Finds the logind session this compositor belongs to.
///
/// The compositor runs as a systemd user service, outside the session scope,
/// so "the caller's session" does not resolve. The session wrapper imports
/// `XDG_SESSION_ID` into the user manager environment; when it is missing the
/// user's display session is used instead.
async fn resolve_session(
    connection: &Connection,
    manager: &Proxy<'_>,
) -> zbus::Result<OwnedObjectPath> {
    if let Ok(id) = std::env::var("XDG_SESSION_ID") {
        if !id.is_empty() {
            match manager.call("GetSession", &(id.as_str(),)).await {
                Ok(path) => return Ok(path),
                Err(error) => debug!(?error, %id, "XDG_SESSION_ID is not a live session"),
            }
        }
    }
    let user = Proxy::new(
        connection,
        LOGIN1_NAME,
        format!("{LOGIN1_PATH}/user/_{}", unsafe { libc::getuid() }),
        LOGIN1_USER,
    )
    .await?;
    let (_, path): (String, OwnedObjectPath) = user.get_property("Display").await?;
    if path.as_str() == "/" {
        return Err(zbus::Error::Failure(
            "the user has no display session".into(),
        ));
    }
    Ok(path)
}

/// Asks logind to wait for us before suspending, so the machine never resumes
/// on an unlocked desktop. logind still proceeds after `InhibitDelayMaxSec`.
async fn take_sleep_inhibitor(manager: &Proxy<'_>) -> Option<OwnedFd> {
    match manager
        .call(
            "Inhibit",
            &(
                "sleep",
                "Veshell",
                "Lock the screen before suspend",
                "delay",
            ),
        )
        .await
    {
        Ok(fd) => Some(fd),
        Err(error) => {
            warn!(?error, "Failed to take the sleep inhibitor");
            None
        }
    }
}
