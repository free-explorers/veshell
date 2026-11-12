//! Thin FFI over libxkbregistry (`xkbcommon/xkbregistry.h`).
//!
//! The registry is the same catalogue GNOME's input-source picker uses. It
//! parses the XKB rules (`evdev.xml`) and yields one entry per layout and per
//! variant, each with a human-readable description and its ISO language and
//! country codes. We link the library directly — it ships in the libxkbcommon
//! the compositor already uses — so the list cannot drift from what
//! [`smithay::input::keyboard::XkbConfig`] can compile, with no subprocess and
//! no parsing of the host's files.

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_uint};

use serde::Serialize;

/// Opaque libxkbregistry handles. We never dereference them; they are only
/// passed back to the C API.
#[repr(C)]
struct RxkbContext {
    _private: [u8; 0],
}

#[repr(C)]
struct RxkbLayout {
    _private: [u8; 0],
}

#[repr(C)]
struct RxkbOptionGroup {
    _private: [u8; 0],
}

#[repr(C)]
struct RxkbOption {
    _private: [u8; 0],
}

#[repr(C)]
struct RxkbIso639Code {
    _private: [u8; 0],
}

#[repr(C)]
struct RxkbIso3166Code {
    _private: [u8; 0],
}

/// `enum rxkb_context_flags`; see `xkbregistry.h`.
const RXKB_CONTEXT_NO_FLAGS: c_uint = 0;
const RXKB_CONTEXT_LOAD_EXOTIC_RULES: c_uint = 1 << 1;

#[link(name = "xkbregistry")]
extern "C" {
    fn rxkb_context_new(flags: c_uint) -> *mut RxkbContext;
    fn rxkb_context_parse(context: *mut RxkbContext, ruleset: *const c_char) -> bool;
    fn rxkb_context_unref(context: *mut RxkbContext);

    fn rxkb_layout_first(context: *mut RxkbContext) -> *mut RxkbLayout;
    fn rxkb_layout_next(layout: *mut RxkbLayout) -> *mut RxkbLayout;
    fn rxkb_layout_get_name(layout: *mut RxkbLayout) -> *const c_char;
    fn rxkb_layout_get_variant(layout: *mut RxkbLayout) -> *const c_char;
    fn rxkb_layout_get_brief(layout: *mut RxkbLayout) -> *const c_char;
    fn rxkb_layout_get_description(layout: *mut RxkbLayout) -> *const c_char;

    fn rxkb_layout_get_iso639_first(layout: *mut RxkbLayout) -> *mut RxkbIso639Code;
    fn rxkb_iso639_code_next(code: *mut RxkbIso639Code) -> *mut RxkbIso639Code;
    fn rxkb_iso639_code_get_code(code: *mut RxkbIso639Code) -> *const c_char;

    fn rxkb_layout_get_iso3166_first(layout: *mut RxkbLayout) -> *mut RxkbIso3166Code;
    fn rxkb_iso3166_code_next(code: *mut RxkbIso3166Code) -> *mut RxkbIso3166Code;
    fn rxkb_iso3166_code_get_code(code: *mut RxkbIso3166Code) -> *const c_char;

    fn rxkb_option_group_first(context: *mut RxkbContext) -> *mut RxkbOptionGroup;
    fn rxkb_option_group_next(group: *mut RxkbOptionGroup) -> *mut RxkbOptionGroup;
    fn rxkb_option_group_get_name(group: *mut RxkbOptionGroup) -> *const c_char;
    fn rxkb_option_group_get_description(group: *mut RxkbOptionGroup) -> *const c_char;
    fn rxkb_option_group_allows_multiple(group: *mut RxkbOptionGroup) -> bool;

    fn rxkb_option_first(group: *mut RxkbOptionGroup) -> *mut RxkbOption;
    fn rxkb_option_next(option: *mut RxkbOption) -> *mut RxkbOption;
    fn rxkb_option_get_name(option: *mut RxkbOption) -> *const c_char;
    fn rxkb_option_get_description(option: *mut RxkbOption) -> *const c_char;
}

/// One selectable layout entry: a base layout (`variant` empty) or one of its
/// variants.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct KeyboardLayout {
    /// The xkb layout name, e.g. `us`.
    pub layout: String,
    /// The xkb variant name, e.g. `altgr-intl`; empty for a base layout.
    pub variant: String,
    /// The ISO 639-1 language code, e.g. `en`.
    pub brief: String,
    /// The label shown in the picker, e.g. `English (intl., with AltGr dead keys)`.
    pub description: String,
    /// ISO 639 language codes the layout maps to.
    #[serde(rename = "iso639")]
    pub iso639: Vec<String>,
    /// ISO 3166 country codes the layout maps to.
    #[serde(rename = "iso3166")]
    pub iso3166: Vec<String>,
}

/// One xkb option group, e.g. `compose` ("Position of Compose key").
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct KeyboardOptionGroup {
    /// The group name (`ctrl`). Not always the prefix of its options: the
    /// compose group is named `Compose key`, and `compat` holds `numpad:*`.
    pub name: String,
    /// The label shown in the picker.
    pub description: String,
    /// Whether several options of the group can be set together; when not,
    /// picking one replaces the other.
    pub allows_multiple: bool,
    pub options: Vec<KeyboardOption>,
}

/// One xkb option, e.g. `compose:ralt` ("Right Alt").
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct KeyboardOption {
    /// The full option name, as stored in `keyboard.options`.
    pub name: String,
    /// The label shown in the picker.
    pub description: String,
}

/// Lists every layout and variant in the `evdev` ruleset.
///
/// [`include_exotic`] loads the extra rulesets too (GNOME's "show all
/// sources"), which adds the rarely used entries.
pub fn list_keyboard_layouts(include_exotic: bool) -> Result<Vec<KeyboardLayout>, String> {
    // SAFETY: the layout handles are only read while the context is alive.
    with_evdev_context(include_exotic, |context| unsafe {
        let mut layouts = Vec::new();
        let mut layout = rxkb_layout_first(context);
        while !layout.is_null() {
            layouts.push(read_layout(layout));
            layout = rxkb_layout_next(layout);
        }
        layouts
    })
}

/// Lists every option group in the `evdev` ruleset, with its options.
///
/// Groups without a single option are left out: there is nothing to pick.
pub fn list_keyboard_options(include_exotic: bool) -> Result<Vec<KeyboardOptionGroup>, String> {
    // SAFETY: the group and option handles are only read while the context
    // is alive.
    with_evdev_context(include_exotic, |context| unsafe {
        let mut groups = Vec::new();
        let mut group = rxkb_option_group_first(context);
        while !group.is_null() {
            let mut options = Vec::new();
            let mut option = rxkb_option_first(group);
            while !option.is_null() {
                options.push(KeyboardOption {
                    name: owned_string(rxkb_option_get_name(option)),
                    description: owned_string(rxkb_option_get_description(option)),
                });
                option = rxkb_option_next(option);
            }
            if !options.is_empty() {
                groups.push(KeyboardOptionGroup {
                    name: owned_string(rxkb_option_group_get_name(group)),
                    description: owned_string(rxkb_option_group_get_description(group)),
                    allows_multiple: rxkb_option_group_allows_multiple(group),
                    options,
                });
            }
            group = rxkb_option_group_next(group);
        }
        groups
    })
}

/// Parses the `evdev` ruleset, the one GNOME and xkbcommon's own tools
/// default to, and runs `read` on it before releasing the context.
fn with_evdev_context<T>(
    include_exotic: bool,
    read: impl FnOnce(*mut RxkbContext) -> T,
) -> Result<T, String> {
    let flags = if include_exotic {
        RXKB_CONTEXT_LOAD_EXOTIC_RULES
    } else {
        RXKB_CONTEXT_NO_FLAGS
    };
    let ruleset = CString::new("evdev").map_err(|_| "invalid ruleset name".to_owned())?;

    // SAFETY: the context is checked for null, only passed back to the same C
    // API, and released once `read` has copied what it needs out of it.
    unsafe {
        let context = rxkb_context_new(flags);
        if context.is_null() {
            return Err("libxkbregistry could not create a context".to_owned());
        }
        if !rxkb_context_parse(context, ruleset.as_ptr()) {
            rxkb_context_unref(context);
            return Err("libxkbregistry could not parse the 'evdev' ruleset".to_owned());
        }
        let value = read(context);
        rxkb_context_unref(context);
        Ok(value)
    }
}

/// # Safety
/// `layout` must be a live handle borrowed from a parsed context.
unsafe fn read_layout(layout: *mut RxkbLayout) -> KeyboardLayout {
    KeyboardLayout {
        layout: owned_string(rxkb_layout_get_name(layout)),
        variant: owned_string(rxkb_layout_get_variant(layout)),
        brief: owned_string(rxkb_layout_get_brief(layout)),
        description: owned_string(rxkb_layout_get_description(layout)),
        iso639: read_iso639(rxkb_layout_get_iso639_first(layout)),
        iso3166: read_iso3166(rxkb_layout_get_iso3166_first(layout)),
    }
}

/// Copies a NUL-terminated string the registry owns. A null pointer (an absent
/// variant, say) becomes an empty string.
///
/// # Safety
/// `pointer` must be null or a valid NUL-terminated C string.
unsafe fn owned_string(pointer: *const c_char) -> String {
    if pointer.is_null() {
        String::new()
    } else {
        CStr::from_ptr(pointer).to_string_lossy().into_owned()
    }
}

/// # Safety
/// `code` must be null or a live handle from the same registry.
unsafe fn read_iso639(mut code: *mut RxkbIso639Code) -> Vec<String> {
    let mut codes = Vec::new();
    while !code.is_null() {
        let value = owned_string(rxkb_iso639_code_get_code(code));
        if !value.is_empty() {
            codes.push(value);
        }
        code = rxkb_iso639_code_next(code);
    }
    codes
}

/// # Safety
/// `code` must be null or a live handle from the same registry.
unsafe fn read_iso3166(mut code: *mut RxkbIso3166Code) -> Vec<String> {
    let mut codes = Vec::new();
    while !code.is_null() {
        let value = owned_string(rxkb_iso3166_code_get_code(code));
        if !value.is_empty() {
            codes.push(value);
        }
        code = rxkb_iso3166_code_next(code);
    }
    codes
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The registry reads the host's XKB data. This runs where that data is
    /// installed (a developer machine); elsewhere it is skipped rather than
    /// failing the suite.
    #[test]
    fn lists_the_evdev_ruleset_when_available() {
        let Ok(layouts) = list_keyboard_layouts(false) else {
            return;
        };
        if layouts.is_empty() {
            return;
        }
        assert!(
            layouts
                .iter()
                .any(|layout| layout.layout == "us" && layout.variant == "altgr-intl"),
            "the evdev ruleset should contain the us(altgr-intl) variant"
        );
        assert!(layouts.iter().all(|layout| !layout.description.is_empty()));
    }

    #[test]
    fn lists_the_compose_options_when_available() {
        let Ok(groups) = list_keyboard_options(false) else {
            return;
        };
        if groups.is_empty() {
            return;
        }
        assert!(
            groups
                .iter()
                .flat_map(|group| &group.options)
                .any(|option| option.name == "compose:ralt"),
            "the evdev ruleset should contain the compose:ralt option"
        );
        assert!(groups
            .iter()
            .flat_map(|group| &group.options)
            .all(|option| option.name.starts_with(|c: char| c.is_ascii_alphanumeric())));
    }
}
