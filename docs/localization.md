# Localization

Veshell uses Flutter's built-in `gen-l10n` and ARB catalogs, following
[Flutter's internationalization guide](https://docs.flutter.dev/ui/internationalization).
English (`src/shell/lib/l10n/app_en.arb`) is the source language and fallback.
App roots must use `shellLocalizationsDelegates` from `lib/l10n/l10n.dart`,
not just the generated delegates: `material_ui` and its Cupertino dependency
have separate localization types from Flutter's SDK widgets. The shared list
provides both, including in navigator dialogs and overlays.
The app ships English, Arabic, Bengali, Chinese (Simplified and Traditional),
French, German, Hindi, Indonesian, Italian, Japanese, Korean, Polish,
Portuguese (including Brazil and Portugal variants), Russian, Spanish,
Turkish, Urdu, and Vietnamese. Adding a system locale does not
add a Veshell translation. English stays first in the generated supported
locale list through `preferred-supported-locales` in `src/shell/l10n.yaml`,
so unsupported system languages continue to fall back to English.

## Fonts

The shell requests system-installed Roboto and Noto fallbacks for every shipped
script through Fontconfig. Both themes and tooltips use these families.
CJK fallback ordering follows the Veshell language (including Traditional
Chinese), while all fallbacks remain available for mixed-script labels.
Install the distribution font packages listed in `docs/dependencies.md`;
font files are not vendored or downloaded by the shell. Font versions and
rendering follow the distribution and local Fontconfig configuration.
Flutter tests check theme/fallback configuration, not host font availability.
Run `python3 extra/tests/system_fonts.py` to check installed families and
translation glyph coverage. When adding a new script, update the fallback
list, distribution dependencies and this runtime check.

## System locale editor

Settings → Language and Region → System locale edits Linux's system-wide
defaults through `org.freedesktop.locale1` on the system bus. A single default
locale (`LANG`) dropdown lists installed locales from `locale -a` once each,
without encoding suffixes. Selecting a locale prefers its installed UTF-8
variant, falling back to an installed legacy variant when necessary. Modifiers
such as `@latin` remain distinct. Existing encodings are not changed merely by
opening the editor. Message-language and regional overrides are not exposed;
changes preserve all other locale assignments, including `LC_*` and `LANGUAGE`.
They never go into Veshell's `settings.json` or directly overwrite
`/etc/locale.conf`.

Both locale dropdowns use the reusable `DropdownSettingEditor`: selecting an
option stages it, and the inline check saves it and closes the expanded editor.
The system locale check requests interactive Polkit authorization. The editor reports service,
locale-list, authorization, and save failures, and detects concurrent changes
instead of silently overwriting another settings client's edits. It does not
generate locales or modify keyboard settings. Missing `systemd-localed` leaves
the editor unavailable rather than falling back to privileged file writes.

Successful changes update Veshell's automatic locale resolution and the
"Same as system" choice immediately. Existing external applications and the
session's environment may still require logging out and back in; per-user environment
overrides can still take precedence. No automatic logout is performed.

## Adding or changing text

### Veshell language preference

Settings always shows **Veshell language** immediately after **System locale**.
It lists only generated `AppLocalizations.supportedLocales`, not Linux's installed
locales. Each catalog's `languageAutonym` supplies its native-language label.
All shipped languages and regional variants are available, labeled in their own language.

Before reading locale1, the picker uses the session's language preferences.
Once the system editor has loaded or saved its configuration, it uses the
latest configured message languages (`LANGUAGE`, `LC_MESSAGES`, and `LANG`)
instead, without requiring a logout.
Failed reads or writes do not replace the last known preferences. External
desktop-entry metadata continues using the running session's languages.

The selection is saved as `system.language` (a BCP-47 tag) in Veshell's
`settings.json` and applies immediately to all monitor roots and localized
providers. It does not change Linux locales or external application metadata.
An explicit language selection overrides the system, even when a system
language is supported. If any system language matches a shipped catalog,
**Same as system** is offered and selected by default when there is no valid
override. Selecting it clears `system.language` and restores automatic
resolution, when confirmed with the inline check. Unsupported system languages fall back to English; the picker
still offers all shipped catalogs, but not a misleading "Same as system" choice.
Unknown or removed catalog tags fall back safely to normal locale resolution.
Chinese regional preferences for Taiwan, Hong Kong, and Macao select Traditional
Chinese when no explicit script is specified; explicit scripts take precedence.
The generic Chinese catalog remains Simplified Chinese. Portuguese regional
preferences select the Brazilian or European catalog when appropriate, with
the generic Portuguese catalog available for other regions.

### Catalog messages

- Add a semantic camelCase key to `app_en.arb`. Use complete messages, not
  concatenated sentence fragments.
- For dynamic values, add an `@key` entry with a description and typed
  `placeholders`. Use ICU plurals for counts; never append an English `s`.
- Widgets use `context.l10n` from `package:shell/l10n/l10n.dart`.
- Providers watch `shellLocalizationsProvider` when deriving display text,
  or read it when creating a notification or reporting an action's error.
- Use locale-aware `intl` date skeletons and number formatting. Standard
  SI/IEC symbols remain technical values; `context.measurement` formats
  their numbers and the catalog controls the number/unit arrangement.
- Do not translate configuration keys, enum serialization values, D-Bus or
  platform-channel identifiers, logs, developer-inspector property names,
  filenames, or text supplied by another application. Desktop entries use
  their own translations and the system locale.

Regenerate from `src/shell/`:

```sh
../../.flutter_sdk/bin/flutter gen-l10n
```

Generated `app_localizations*.dart` files are build output, not editable
translation sources. `flutter: generate: true` also regenerates them during
pub-get/build, using `l10n.yaml`. `cargo check` is the full compilation gate.

## Adding a language

Add `app_<locale>.arb` beside `app_en.arb`, with `@@locale` and translated
message keys. Preserve placeholder names and types, and adapt ICU plural
categories to the target language. Regenerate; supported locales and Flutter
Material/Cupertino/widget delegates are generated automatically. Check missing
translations in the generator output before considering a catalog complete.
Translate `languageAutonym` to the language's own name (including region or
script if needed to distinguish it in the picker).

The Rust embedder sends locale preferences from `LANGUAGE` and
`LC_ALL`/`LC_MESSAGES`/`LANG` to Flutter at startup. C/POSIX falls back to
English. Flutter resolves the supported locale once for all monitor roots;
provider-generated text uses that same locale. Each monitor's dialogs and
overlays inherit its localization delegates. Platform locale changes update
the providers and roots; environment-variable changes require a restart.

Test with the project SDK:

```sh
../../.flutter_sdk/bin/flutter test
```

`l10n_test.dart` covers fallback, placeholders, plurals, locale changes, and
dialog delegates. `veshell_language_test.dart` covers conditional picker
ordering, shipped-only choices, preference resolution, clearing overrides,
and persistence.
`l10n_extraction_test.dart` guards common UI text boundaries
against new hardcoded strings. `translation_catalogs_test.dart` checks all
catalogs for completeness, locale selection, placeholders, Russian, Polish and Arabic
plural forms, and delegate loading and text direction for every language.
`system_locale_test.dart` covers staged edits,
regional override preservation, authorization failures, concurrent edits, and
the locale1 D-Bus contract on a private test bus (without changing host locales).
Rust tests cover Linux locale parsing and
preference ordering. New translations should additionally be checked visually
for long text, clipping, and right-to-left layout (Arabic and Urdu), and reviewed by
native speakers for translation quality.
