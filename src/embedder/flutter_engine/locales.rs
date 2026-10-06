//! Pass Linux message-language preferences to Flutter's platform dispatcher.

use std::{env, ffi::CString, mem::size_of, ptr::null};

use super::embedder::{FlutterEngine, FlutterEngineUpdateLocales, FlutterLocale};

#[derive(Debug, PartialEq, Eq)]
struct Locale {
    language: String,
    country: Option<String>,
    script: Option<String>,
}

fn parse_locale(value: &str) -> Option<Locale> {
    let value = value.trim();
    let (base, modifier) = value.split_once('@').unwrap_or((value, ""));
    let base = base.split('.').next()?;
    if base == "C" || base == "POSIX" {
        return Some(Locale {
            language: "en".into(),
            country: Some("US".into()),
            script: None,
        });
    }
    let mut parts = base.split(['_', '-']);
    let language = parts.next()?;
    if !(2..=3).contains(&language.len()) || !language.bytes().all(|c| c.is_ascii_alphabetic()) {
        return None;
    }
    let mut locale = Locale {
        language: language.to_ascii_lowercase(),
        country: None,
        script: match modifier {
            "latin" => Some("Latn".into()),
            "cyrillic" => Some("Cyrl".into()),
            _ => None,
        },
    };
    for part in parts {
        if part.len() == 4 && part.bytes().all(|c| c.is_ascii_alphabetic()) {
            let mut script = part.to_ascii_lowercase();
            script[..1].make_ascii_uppercase();
            locale.script = Some(script);
        } else if (part.len() == 2 && part.bytes().all(|c| c.is_ascii_alphabetic()))
            || (part.len() == 3 && part.bytes().all(|c| c.is_ascii_digit()))
        {
            locale.country = Some(part.to_ascii_uppercase());
        } else {
            return None;
        }
    }
    Some(locale)
}

fn preferred_locales(get: impl Fn(&str) -> Option<String>) -> Vec<Locale> {
    let message_locale = ["LC_ALL", "LC_MESSAGES", "LANG"]
        .into_iter()
        .filter_map(&get)
        .find(|value| !value.trim().is_empty())
        .unwrap_or_else(|| "C".into());
    let is_c = matches!(message_locale.split('.').next(), Some("C" | "POSIX"));
    let mut locales = Vec::new();
    // Like gettext, LANGUAGE is ignored in the C/POSIX message locale.
    if !is_c {
        if let Some(language) = get("LANGUAGE") {
            for value in language.split(':') {
                if let Some(locale) = parse_locale(value) {
                    if !locales.contains(&locale) {
                        locales.push(locale);
                    }
                }
            }
        }
    }
    if let Some(locale) = parse_locale(&message_locale) {
        if !locales.contains(&locale) {
            locales.push(locale);
        }
    }
    if locales.is_empty() {
        locales.push(parse_locale("C").unwrap());
    }
    locales
}

pub(super) fn update_engine_locales(engine: FlutterEngine) -> Result<(), String> {
    let locales = preferred_locales(|key| env::var(key).ok());
    let strings: Vec<_> = locales
        .iter()
        .map(|locale| {
            (
                CString::new(locale.language.as_str()).unwrap(),
                locale.country.as_deref().map(|s| CString::new(s).unwrap()),
                locale.script.as_deref().map(|s| CString::new(s).unwrap()),
            )
        })
        .collect();
    let flutter_locales: Vec<_> = strings
        .iter()
        .map(|(language, country, script)| FlutterLocale {
            struct_size: size_of::<FlutterLocale>(),
            language_code: language.as_ptr(),
            country_code: country.as_ref().map_or(null(), |s| s.as_ptr()),
            script_code: script.as_ref().map_or(null(), |s| s.as_ptr()),
            variant_code: null(),
        })
        .collect();
    let mut pointers: Vec<_> = flutter_locales
        .iter()
        .map(|locale| locale as *const _)
        .collect();
    // Flutter copies these strings during the call. All pointees stay alive
    // until it returns; this runs on the engine's platform thread.
    let result =
        unsafe { FlutterEngineUpdateLocales(engine, pointers.as_mut_ptr(), pointers.len()) };
    if result != 0 {
        return Err(format!("Could not update Flutter locales, error {result}"));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_posix_and_script_locales() {
        assert_eq!(
            parse_locale("fr_BE.UTF-8").unwrap().country.as_deref(),
            Some("BE")
        );
        assert_eq!(
            parse_locale("sr_RS@latin").unwrap().script.as_deref(),
            Some("Latn")
        );
        assert_eq!(
            parse_locale("zh-Hant-TW").unwrap().script.as_deref(),
            Some("Hant")
        );
        assert_eq!(parse_locale("C.UTF-8").unwrap().language, "en");
        assert!(parse_locale("invalid/path").is_none());
        assert!(parse_locale("fr\0").is_none());
    }

    #[test]
    fn honors_precedence_and_language_fallbacks() {
        let vars = [
            ("LC_ALL", "fr_BE.UTF-8"),
            ("LC_MESSAGES", "de_DE"),
            ("LANG", "en_US"),
            ("LANGUAGE", "fr:de:fr"),
        ];
        let locales = preferred_locales(|key| {
            vars.iter()
                .find(|(k, _)| *k == key)
                .map(|(_, v)| v.to_string())
        });
        assert_eq!(
            locales
                .iter()
                .map(|l| l.language.as_str())
                .collect::<Vec<_>>(),
            ["fr", "de", "fr"]
        );
        assert_eq!(locales.last().unwrap().country.as_deref(), Some("BE"));
    }

    #[test]
    fn c_and_invalid_locales_fall_back_to_english() {
        for value in ["C", "POSIX", "C.UTF-8", "invalid"] {
            let locales = preferred_locales(|key| match key {
                "LANG" => Some(value.into()),
                _ => None,
            });
            assert_eq!(locales[0].language, "en");
        }
        let locales = preferred_locales(|key| match key {
            "LANG" => Some("C".into()),
            "LANGUAGE" => Some("fr:de".into()),
            _ => None,
        });
        assert_eq!(locales.len(), 1);
        assert_eq!(locales[0].language, "en");
    }
}
