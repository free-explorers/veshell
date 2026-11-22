//! Which of the engine's renderers draws the shell.
//!
//! Impeller is the default. `VESHELL_RENDERER=skia` falls back to Skia for a
//! driver Impeller renders wrong on, or not at all: the engine reports no
//! error when Impeller cannot start, it only renders nothing.

use tracing::{info, warn};

/// The variable naming the renderer, read once when the engine starts.
const RENDERER_VARIABLE: &str = "VESHELL_RENDERER";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Renderer {
    Impeller,
    Skia,
}

impl Renderer {
    /// The renderer `VESHELL_RENDERER` names, Impeller when it names none.
    pub fn from_env() -> Self {
        let value = std::env::var(RENDERER_VARIABLE).ok();
        let renderer = Self::parse(value.as_deref());
        if renderer.is_none() {
            warn!(
                value,
                "Unknown {RENDERER_VARIABLE} (impeller or skia): using Impeller"
            );
        }
        let renderer = renderer.unwrap_or(Self::Impeller);
        info!(?renderer, "Flutter renderer");
        renderer
    }

    /// `None` for a value naming no renderer; an unset or empty one is the
    /// default.
    fn parse(value: Option<&str>) -> Option<Self> {
        match value.map(str::trim).map(str::to_ascii_lowercase).as_deref() {
            None | Some("") | Some("impeller") => Some(Self::Impeller),
            Some("skia") => Some(Self::Skia),
            Some(_) => None,
        }
    }

    /// The engine's command line switches selecting this renderer.
    pub fn engine_switches(self) -> &'static [&'static str] {
        match self {
            // SDFs give rectangles, rounded rectangles, circles and lines
            // analytic antialiasing, whatever the multisampling of the
            // framebuffers Veshell hands the engine (the
            // `theme.antialiasing` setting, which may be off).
            Self::Impeller => &["--enable-impeller", "--impeller-use-sdfs"],
            // The engine renders with Skia unless told otherwise.
            Self::Skia => &[],
        }
    }

    /// Whether the renderer needs multisampled render targets to antialias.
    ///
    /// Impeller antialiases paths and clips through multisampling. Skia
    /// antialiases everything analytically: samples would only cost memory
    /// and bandwidth.
    pub fn multisamples(self) -> bool {
        self == Self::Impeller
    }
}

#[cfg(test)]
mod tests {
    use super::Renderer;

    #[test]
    fn impeller_is_the_default() {
        assert_eq!(Renderer::parse(None), Some(Renderer::Impeller));
        assert_eq!(Renderer::parse(Some("")), Some(Renderer::Impeller));
        assert_eq!(Renderer::parse(Some("impeller")), Some(Renderer::Impeller));
    }

    #[test]
    fn skia_is_named_in_any_case() {
        assert_eq!(Renderer::parse(Some("skia")), Some(Renderer::Skia));
        assert_eq!(Renderer::parse(Some(" Skia ")), Some(Renderer::Skia));
    }

    #[test]
    fn an_unknown_renderer_is_reported() {
        assert_eq!(Renderer::parse(Some("vulkan")), None);
    }
}
