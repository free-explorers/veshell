//! Command-line parsing for the compositor binary.
//!
//! The parser is deliberately small and pure: `--version` and `--help` must be
//! answered before logging, the DRM backend, Flutter or the session bus are
//! touched, so the caller runs [`Cli::parse`] first.

/// What the process should do after parsing its arguments.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Action {
    /// Start the compositor.
    Run,
    /// Print [`Cli::USAGE`] and exit successfully.
    Help,
    /// Print the embedded build identity and exit successfully.
    Version,
}

/// The parsed command line.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Cli {
    /// Whether `--session` was requested.
    pub session: bool,
    /// The requested action.
    pub action: Action,
}

impl Cli {
    /// Usage text shown by `--help` and after an argument error.
    pub const USAGE: &'static str = "\
Usage: veshell [OPTIONS]

Options:
      --session   Start as a real session, using the DRM backend
  -V, --version   Print the installed binary's version and build identity
  -h, --help      Print this help
";

    /// Parses arguments after the program name.
    ///
    /// Unknown options are errors: a typo such as `--versoin` must not silently
    /// start a compositor on the current VT.
    pub fn parse<I>(arguments: I) -> Result<Self, String>
    where
        I: IntoIterator<Item = String>,
    {
        let mut session = false;
        let mut action = Action::Run;

        for argument in arguments {
            match argument.as_str() {
                "--session" => session = true,
                "-V" | "--version" => action = Action::Version,
                "-h" | "--help" => action = Action::Help,
                other if other.starts_with('-') => {
                    return Err(format!("unrecognized option `{other}`"));
                }
                other => return Err(format!("unexpected argument `{other}`")),
            }
        }

        Ok(Self { session, action })
    }
}

#[cfg(test)]
mod tests {
    use super::{Action, Cli};

    fn parse(arguments: &[&str]) -> Result<Cli, String> {
        Cli::parse(arguments.iter().map(|argument| (*argument).to_owned()))
    }

    #[test]
    fn no_arguments_starts_the_compositor() {
        assert_eq!(
            parse(&[]),
            Ok(Cli {
                session: false,
                action: Action::Run,
            })
        );
    }

    #[test]
    fn session_is_kept_for_backend_selection() {
        assert_eq!(
            parse(&["--session"]),
            Ok(Cli {
                session: true,
                action: Action::Run,
            })
        );
    }

    #[test]
    fn version_wins_over_starting_a_session() {
        assert_eq!(
            parse(&["--session", "--version"]),
            Ok(Cli {
                session: true,
                action: Action::Version,
            })
        );
        assert_eq!(
            parse(&["-V"]),
            Ok(Cli {
                session: false,
                action: Action::Version,
            })
        );
    }

    #[test]
    fn help_is_available() {
        assert_eq!(
            parse(&["--help"]),
            Ok(Cli {
                session: false,
                action: Action::Help,
            })
        );
        assert_eq!(parse(&["-h"]).unwrap().action, Action::Help);
    }

    #[test]
    fn unknown_options_and_positionals_are_errors() {
        assert!(parse(&["--versoin"]).unwrap_err().contains("--versoin"));
        assert!(parse(&["launch"]).unwrap_err().contains("launch"));
        assert!(parse(&["-v"]).is_err());
    }
}
