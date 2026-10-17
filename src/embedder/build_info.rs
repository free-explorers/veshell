//! Compile-time identity of the compositor binary.
//!
//! The version comes from Cargo. The revision and channel are optional build
//! inputs because hermetic builds (Nix, distro source tarballs) have no `.git`
//! checkout: packaging supplies them through `VESHELL_BUILD_COMMIT` and
//! `VESHELL_BUILD_CHANNEL` instead of the build script guessing.

use std::fmt;

/// The build identity reported by `veshell --version`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct BuildInfo {
    /// The Cargo package version, for example `0.1.5`.
    pub version: &'static str,
    /// The source revision, or `None` when the build system did not supply one.
    pub commit: Option<&'static str>,
    /// The release channel, or `None` when the build system did not supply one.
    pub channel: Option<&'static str>,
    /// The Flutter runtime mode (`debug`, `profile` or `release`).
    pub profile: &'static str,
}

impl BuildInfo {
    /// The identity embedded in this compositor binary.
    pub fn current() -> Self {
        Self {
            version: env!("CARGO_PKG_VERSION"),
            commit: non_empty(option_env!("VESHELL_BUILD_COMMIT")),
            channel: non_empty(option_env!("VESHELL_BUILD_CHANNEL")),
            profile: non_empty(option_env!("CARGO_PROFILE")).unwrap_or("debug"),
        }
    }
}

impl fmt::Display for BuildInfo {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "veshell {} (commit {}",
            self.version,
            self.commit.unwrap_or("unknown")
        )?;
        if let Some(channel) = self.channel {
            write!(formatter, ", channel {channel}")?;
        }
        write!(formatter, ", build {})", self.profile)
    }
}

fn non_empty(value: Option<&'static str>) -> Option<&'static str> {
    value.filter(|value| !value.is_empty())
}

#[cfg(test)]
mod tests {
    use super::BuildInfo;

    fn info(commit: Option<&'static str>, channel: Option<&'static str>) -> BuildInfo {
        BuildInfo {
            version: "1.2.3",
            commit,
            channel,
            profile: "release",
        }
    }

    #[test]
    fn display_includes_every_known_field() {
        assert_eq!(
            info(Some("abc123"), Some("beta")).to_string(),
            "veshell 1.2.3 (commit abc123, channel beta, build release)"
        );
    }

    #[test]
    fn display_marks_missing_provenance_as_unknown() {
        assert_eq!(
            info(None, None).to_string(),
            "veshell 1.2.3 (commit unknown, build release)"
        );
    }
}
