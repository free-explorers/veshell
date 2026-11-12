//! Compose sequences and dead keys for the shell's own text fields.
//!
//! Clients compose on their own with libxkbcommon, from the keysyms the seat
//! keymap hands them (`Multi_key`, `dead_acute`, ...). The shell's text input
//! inserts characters itself (see `flutter_engine::text_input`), so it runs
//! the same compose machinery, from the user's locale, before typing a key.

use std::ffi::OsString;

use xkbcommon::xkb::compose::{
    FeedResult, State as ComposeState, Status, Table, COMPILE_NO_FLAGS, STATE_NO_FLAGS,
};
use xkbcommon::xkb::{Context, Keysym, CONTEXT_NO_FLAGS};

/// What a key press does once compose has seen it.
#[derive(Debug, PartialEq, Eq)]
pub enum ComposeOutcome {
    /// Not part of a sequence: the key types as usual.
    Pass,
    /// The key started, continued or cancelled a sequence: it types nothing.
    Swallowed,
    /// The key completed a sequence: type this text instead of the key.
    Composed(String),
}

/// The compose state of the shell's text input. Without a compose table for
/// the locale, every key passes through unchanged.
pub struct Composer {
    state: Option<ComposeState>,
}

impl Composer {
    /// Loads the compose table of the user's locale, the way GTK and Qt do:
    /// the first non-empty of `LC_ALL`, `LC_CTYPE` and `LANG`, else `C`.
    pub fn from_locale() -> Self {
        let locale = ["LC_ALL", "LC_CTYPE", "LANG"]
            .into_iter()
            .filter_map(std::env::var_os)
            .find(|value| !value.is_empty())
            .unwrap_or_else(|| OsString::from("C"));
        let context = Context::new(CONTEXT_NO_FLAGS);
        let table = Table::new_from_locale(&context, &locale, COMPILE_NO_FLAGS).ok();
        if table.is_none() {
            tracing::warn!(?locale, "No compose table for the locale");
        }
        Self::from_table(table)
    }

    fn from_table(table: Option<Table>) -> Self {
        Self {
            state: table.map(|table| ComposeState::new(&table, STATE_NO_FLAGS)),
        }
    }

    /// Feeds a pressed key's keysym to the current sequence.
    pub fn feed(&mut self, keysym: Keysym) -> ComposeOutcome {
        let Some(state) = self.state.as_mut() else {
            return ComposeOutcome::Pass;
        };
        // Modifiers and other keys compose never looks at leave the sequence
        // as it is.
        if state.feed(keysym) == FeedResult::Ignored {
            return ComposeOutcome::Pass;
        }
        match state.status() {
            Status::Nothing => ComposeOutcome::Pass,
            Status::Composing => ComposeOutcome::Swallowed,
            Status::Composed => {
                let text = state.utf8().or_else(|| {
                    state
                        .keysym()
                        .and_then(|keysym| keysym.key_char())
                        .map(String::from)
                });
                state.reset();
                text.map_or(ComposeOutcome::Swallowed, ComposeOutcome::Composed)
            }
            // A sequence that matches nothing types nothing, as in GTK.
            Status::Cancelled => {
                state.reset();
                ComposeOutcome::Swallowed
            }
        }
    }

    /// Drops a sequence in progress, e.g. when the focused text field changes.
    pub fn reset(&mut self) {
        if let Some(state) = self.state.as_mut() {
            state.reset();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use xkbcommon::xkb::compose::FORMAT_TEXT_V1;

    fn composer() -> Composer {
        let context = Context::new(CONTEXT_NO_FLAGS);
        let table = Table::new_from_buffer(
            &context,
            "<Multi_key> <e> <apostrophe> : \"é\" eacute\n\
             <dead_acute> <e> : \"é\" eacute\n",
            "C",
            FORMAT_TEXT_V1,
            COMPILE_NO_FLAGS,
        )
        .expect("the test compose table compiles");
        Composer::from_table(Some(table))
    }

    #[test]
    fn a_compose_sequence_types_its_result() {
        let mut composer = composer();
        assert_eq!(composer.feed(Keysym::Multi_key), ComposeOutcome::Swallowed);
        assert_eq!(composer.feed(Keysym::e), ComposeOutcome::Swallowed);
        assert_eq!(
            composer.feed(Keysym::apostrophe),
            ComposeOutcome::Composed("é".to_owned())
        );
        // The sequence is over: the next key types itself.
        assert_eq!(composer.feed(Keysym::e), ComposeOutcome::Pass);
    }

    #[test]
    fn a_dead_key_composes_with_the_next_key() {
        let mut composer = composer();
        assert_eq!(composer.feed(Keysym::dead_acute), ComposeOutcome::Swallowed);
        assert_eq!(
            composer.feed(Keysym::e),
            ComposeOutcome::Composed("é".to_owned())
        );
    }

    #[test]
    fn modifiers_do_not_break_a_sequence() {
        let mut composer = composer();
        composer.feed(Keysym::Multi_key);
        composer.feed(Keysym::e);
        assert_eq!(composer.feed(Keysym::Shift_L), ComposeOutcome::Pass);
        assert_eq!(
            composer.feed(Keysym::apostrophe),
            ComposeOutcome::Composed("é".to_owned())
        );
    }

    #[test]
    fn an_unknown_sequence_types_nothing() {
        let mut composer = composer();
        composer.feed(Keysym::Multi_key);
        assert_eq!(composer.feed(Keysym::z), ComposeOutcome::Swallowed);
        assert_eq!(composer.feed(Keysym::z), ComposeOutcome::Pass);
    }

    #[test]
    fn reset_drops_a_sequence_in_progress() {
        let mut composer = composer();
        composer.feed(Keysym::Multi_key);
        composer.reset();
        assert_eq!(composer.feed(Keysym::e), ComposeOutcome::Pass);
    }

    #[test]
    fn without_a_table_every_key_passes() {
        let mut composer = Composer::from_table(None);
        assert_eq!(composer.feed(Keysym::Multi_key), ComposeOutcome::Pass);
    }
}
