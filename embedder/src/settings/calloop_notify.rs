use std::ops::{Deref, DerefMut};

use calloop::channel::{self, Channel, ChannelError, Event as ChannelEvent};
use calloop::{EventSource, Poll, PostAction, Readiness, Token, TokenFactory};
pub use notify;
use notify::{Event, RecommendedWatcher};
use smithay::reexports::calloop;

/// Calloop event source for watching files.
///
/// This struct implements [`EventSource`], which allows passing it to
/// [`LoopHandle::insert_source`] for registering it with calloop.
///
/// Since this implements [`Deref`] and [`DerefMut`] into
/// [`RecommendedWatcher`], you can call any function from [`Watcher`]
/// on it. Use this to [`watch`] new files.
///
/// [`Watcher`]: notify::Watcher
/// [`watch`]: notify::Watcher::watch
///
/// ## Example
///
/// ```rust,no_run
/// use std::path::Path;
///
/// use calloop::EventLoop;
/// use calloop_notify::notify::{RecursiveMode, Watcher};
/// use calloop_notify::NotifySource;
///
/// // Create calloop event loop.
/// let mut event_loop = EventLoop::try_new().unwrap();
/// let loop_handle = event_loop.handle();
///
/// // Watch current directory recursively.
/// let mut notify_source = NotifySource::new().unwrap();
/// notify_source.watch(Path::new("."), RecursiveMode::Recursive).unwrap();
///
/// // Insert notify source into calloop.
/// loop_handle
///     .insert_source(notify_source, |event, _, _: &mut ()| {
///         println!("Notify Event: {event:?}");
///     })
///     .unwrap();
///
/// // Dispatch event loop.
/// loop {
///     event_loop.dispatch(None, &mut ()).unwrap();
/// }
/// ```
///
/// [`LoopHandle::insert_source`]: calloop::LoopHandle::insert_source
pub struct NotifySource {
    watcher: RecommendedWatcher,
    rx: Channel<Event>,
}

impl NotifySource {
    /// Create the event source.
    ///
    /// ## Errors
    ///
    /// If the [`notify`] watcher creation failed.
    ///
    /// ## Example
    ///
    /// ```rust,no_run
    /// use calloop_notify::NotifySource;
    ///
    /// let notify_source = NotifySource::new().unwrap();
    /// ```
    pub fn new() -> Result<Self, notify::Error> {
        let (tx, rx) = channel::channel();

        let watcher = notify::recommended_watcher(move |event| {
            if let Ok(event) = event {
                let _ = tx.send(event);
            }
        })?;

        Ok(Self { watcher, rx })
    }
}

impl Deref for NotifySource {
    type Target = RecommendedWatcher;

    fn deref(&self) -> &Self::Target {
        &self.watcher
    }
}

impl DerefMut for NotifySource {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.watcher
    }
}

impl EventSource for NotifySource {
    type Error = ChannelError;
    type Event = Event;
    type Metadata = ();
    type Ret = ();

    fn process_events<F>(
        &mut self,
        readiness: Readiness,
        token: Token,
        mut callback: F,
    ) -> Result<PostAction, Self::Error>
    where
        F: FnMut(Self::Event, &mut Self::Metadata) -> Self::Ret,
    {
        self.rx.process_events(readiness, token, |event, metadata| match event {
            ChannelEvent::Msg(msg) => callback(msg, metadata),
            ChannelEvent::Closed => (),
        })
    }

    fn register(
        &mut self,
        poll: &mut Poll,
        token_factory: &mut TokenFactory,
    ) -> calloop::Result<()> {
        self.rx.register(poll, token_factory)
    }

    fn reregister(
        &mut self,
        poll: &mut Poll,
        token_factory: &mut TokenFactory,
    ) -> calloop::Result<()> {
        self.rx.reregister(poll, token_factory)
    }

    fn unregister(&mut self, poll: &mut Poll) -> calloop::Result<()> {
        self.rx.unregister(poll)
    }
}