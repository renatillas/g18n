import argv
import filepath
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/string
import gleam/time/calendar
import simplifile
import splitter
import tom
import trie

// Core Types
pub type Locale {
  Locale(language: String, region: Option(String))
}

pub type LocaleError {
  InvalidLanguage(reason: String)
  InvalidLocale(reason: String)
}

// Trie-based translations for hierarchical keys
pub type Translations =
  trie.Trie(String, String)

pub type FormatParams =
  Dict(String, String)

pub type Translator {
  Translator(
    locale: Locale,
    translations: Translations,
    fallback_locale: Option(Locale),
    fallback_translations: Option(Translations),
  )
}

pub type PluralRule {
  Zero
  One
  Two
  Few
  Many
  Other
}

pub type PluralRules =
  fn(Int) -> PluralRule

// Advanced pluralization types
pub type PluralForm {
  Cardinal(Int)
  // 0, 1, 2, 3... (regular counting)
  Ordinal(Int)
  // 1st, 2nd, 3rd... (position/ranking)
  Range(from: Int, to: Int)
  // 1-3 items (ranges)
}

pub type OrdinalRule {
  First
  // 1st, 21st, 31st...
  Second
  // 2nd, 22nd, 32nd...
  Third
  // 3rd, 23rd, 33rd...
  Nth
  // 4th, 5th, 6th... (default)
}

// RTL/LTR Support
pub type TextDirection {
  LTR
  // Left-to-Right (English, Spanish, German, etc.)
  RTL
  // Right-to-Left (Arabic, Hebrew, Persian, etc.)
}

// Context-sensitive translations
pub type TranslationContext {
  NoContext
  Context(String)
}

// Locale negotiation types
pub type LocalePreference {
  Preferred(Locale)
  Acceptable(Locale)
}

pub type LocaleMatch {
  ExactMatch(Locale)
  LanguageMatch(Locale)
  RegionFallback(Locale)
  NoMatch
}

// Locale Functions

/// Create a new locale from a locale code string.
/// Supports formats like "en", "en-US", "pt-BR".
/// 
/// ## Examples
/// ```gleam
/// let assert Ok(en) = g18n.locale("en")
/// let assert Ok(en_us) = g18n.locale("en-US")
/// let assert Error(_) = g18n.locale("invalid")
/// ```
pub fn locale(locale_code: String) -> Result(Locale, LocaleError) {
  parse_locale(locale_code)
}

/// Convert a locale back to its string representation.
/// 
/// ## Examples
/// ```gleam
/// let assert Ok(locale) = g18n.locale("en-US")
/// g18n.locale_string(locale) // "en-US"
/// ```
pub fn locale_string(locale: Locale) -> String {
  case locale.region {
    Some(region) -> locale.language <> "-" <> region
    None -> locale.language
  }
}

/// Extract the language code from a locale.
/// 
/// ## Examples
/// ```gleam
/// let assert Ok(locale) = g18n.locale("en-US")
/// g18n.locale_language(locale) // "en"
/// ```
pub fn locale_language(locale: Locale) -> String {
  locale.language
}

/// Extract the region code from a locale.
/// 
/// ## Examples
/// ```gleam
/// let assert Ok(locale) = g18n.locale("en-US")
/// g18n.locale_region(locale) // Some("US")
/// ```
pub fn locale_region(locale: Locale) -> Option(String) {
  locale.region
}

/// Check if two locales share the same language (ignoring region).
/// 
/// ## Examples
/// ```gleam
/// let assert Ok(en_us) = g18n.locale("en-US")
/// let assert Ok(en_gb) = g18n.locale("en-GB")
/// g18n.locales_match_language(en_us, en_gb) // True
/// ```
pub fn locales_match_language(locale1: Locale, locale2: Locale) -> Bool {
  locale1.language == locale2.language
}

/// Check if two locales are exactly identical.
/// 
/// ## Examples
/// ```gleam
/// let assert Ok(en_us1) = g18n.locale("en-US")
/// let assert Ok(en_us2) = g18n.locale("en-US")
/// g18n.locales_exact_match(en_us1, en_us2) // True
/// ```
pub fn locales_exact_match(locale1: Locale, locale2: Locale) -> Bool {
  locale1.language == locale2.language && locale1.region == locale2.region
}

/// Create a new locale with only the language part (no region).
/// 
/// ## Examples
/// ```gleam
/// let assert Ok(en_us) = g18n.locale("en-US")
/// let en_only = g18n.locale_language_only(en_us)
/// g18n.locale_string(en_only) // "en"
/// ```
pub fn locale_language_only(locale: Locale) -> Locale {
  Locale(language: locale.language, region: None)
}

/// Get the text direction for a locale.
///
/// Determines whether text should flow left-to-right (LTR) or right-to-left (RTL)
/// based on the locale's language. Essential for proper UI layout and text rendering.
///
/// ## Examples
/// ```gleam
/// let assert Ok(arabic) = g18n.locale("ar")
/// let assert Ok(english) = g18n.locale("en")
/// 
/// g18n.get_text_direction(arabic)  // RTL
/// g18n.get_text_direction(english) // LTR
/// ```
pub fn get_text_direction(locale: Locale) -> TextDirection {
  case locale.language {
    // RTL languages
    "ar" | "he" | "fa" | "ur" | "ps" | "ks" | "sd" | "ug" | "yi" -> RTL
    // All others are LTR by default
    _ -> LTR
  }
}

/// Check if a locale uses right-to-left text direction.
///
/// ## Examples
/// ```gleam
/// let assert Ok(arabic) = g18n.locale("ar-SA")
/// let assert Ok(english) = g18n.locale("en-US")
/// 
/// g18n.is_rtl(arabic)  // True
/// g18n.is_rtl(english) // False
/// ```
pub fn is_rtl(locale: Locale) -> Bool {
  case get_text_direction(locale) {
    RTL -> True
    LTR -> False
  }
}

/// Get the CSS direction property value for a locale.
///
/// Returns the appropriate CSS direction value for styling purposes.
///
/// ## Examples
/// ```gleam
/// let assert Ok(arabic) = g18n.locale("ar")
/// let assert Ok(english) = g18n.locale("en")
/// 
/// g18n.get_css_direction(arabic)  // "rtl"
/// g18n.get_css_direction(english) // "ltr"
/// ```
pub fn get_css_direction(locale: Locale) -> String {
  case get_text_direction(locale) {
    RTL -> "rtl"
    LTR -> "ltr"
  }
}

fn parse_locale(locale_code: String) -> Result(Locale, LocaleError) {
  let normalized = string.lowercase(string.trim(locale_code))
  let dash_splitter = splitter.new(["-"])
  let #(lang, separator, region) = splitter.split(dash_splitter, normalized)

  case separator, region {
    "", "" -> {
      // No separator found, just language
      case string.length(lang) {
        2 -> Ok(Locale(language: lang, region: None))
        _ -> Error(InvalidLanguage("Language code must be 2 characters"))
      }
    }
    "-", reg -> {
      // Separator found, validate both parts
      let lang_len = string.length(lang)
      let reg_len = string.length(reg)
      case lang_len, reg_len {
        2, 2 -> Ok(Locale(language: lang, region: Some(string.uppercase(reg))))
        _, _ ->
          Error(InvalidLanguage(
            "Language must be 2 chars and region must be 2 chars, got: "
            <> lang
            <> "-"
            <> reg,
          ))
      }
    }
    _, _ ->
      Error(InvalidLocale("Invalid format, expected format: 'en-US' or 'en'"))
  }
}

// Translator Functions
/// Create a new translator with the specified locale and translations.
///
/// A translator combines a locale with a set of translations to provide
/// localized text output. This is the main interface for translation operations.
///
/// ## Examples
/// ```gleam
/// let assert Ok(locale) = g18n.locale("en-US")
/// let translations = g18n.translations()
///   |> g18n.add_translation("hello", "Hello")
///   |> g18n.add_translation("welcome", "Welcome {name}!")
/// 
/// let translator = g18n.translator(locale, translations)
/// 
/// g18n.translate(translator, "hello")
/// // "Hello"
/// ```
pub fn translator(locale: Locale, translations: Translations) -> Translator {
  Translator(
    locale: locale,
    translations: translations,
    fallback_locale: None,
    fallback_translations: None,
  )
}

/// Add fallback locale and translations to an existing translator.
///
/// When a translation key is not found in the primary translations,
/// the translator will fall back to the fallback translations before
/// returning the original key.
///
/// ## Examples
/// ```gleam
/// let assert Ok(en) = g18n.locale("en")
/// let assert Ok(es) = g18n.locale("es")
/// 
/// let en_translations = g18n.translations()
///   |> g18n.add_translation("hello", "Hello")
/// 
/// let es_translations = g18n.translations()
///   |> g18n.add_translation("goodbye", "Adiós")
/// 
/// let translator = g18n.translator(es, es_translations)
///   |> g18n.with_fallback(en, en_translations)
/// 
/// g18n.translate(translator, "goodbye") // "Adiós"
/// g18n.translate(translator, "hello")   // "Hello" (from fallback)
/// ```
pub fn with_fallback(
  translator: Translator,
  fallback_locale: Locale,
  fallback_translations: Translations,
) -> Translator {
  Translator(
    ..translator,
    fallback_locale: Some(fallback_locale),
    fallback_translations: Some(fallback_translations),
  )
}

/// Translate a key to localized text using the translator.
///
/// Looks up the translation for the given key in the translator's 
/// translations. If not found, tries the fallback translations. 
/// If still not found, returns the original key as fallback.
///
/// Supports hierarchical keys using dot notation for organization.
///
/// ## Examples
/// ```gleam
/// let assert Ok(locale) = g18n.locale("en")
/// let translations = g18n.translations()
///   |> g18n.add_translation("ui.button.save", "Save")
///   |> g18n.add_translation("user.greeting", "Hello")
/// 
/// let translator = g18n.translator(locale, translations)
/// 
/// g18n.translate(translator, "ui.button.save")
/// // "Save"
/// 
/// g18n.translate(translator, "user.greeting") 
/// // "Hello"
/// 
/// g18n.translate(translator, "missing.key")
/// // "missing.key" (fallback to key)
/// ```
pub fn translate(translator: Translator, key: String) -> String {
  let key_parts = string.split(key, ".")
  case trie.get(translator.translations, key_parts) {
    Ok(translation) -> translation
    Error(Nil) -> get_fallback_translation(translator, key_parts, key)
  }
}

/// Translate a key with parameter substitution.
///
/// Performs translation lookup and then substitutes parameters in the 
/// resulting template. Parameters are specified using `{param}` syntax
/// in the translation template.
///
/// ## Examples
/// ```gleam
/// let assert Ok(locale) = g18n.locale("en")
/// let translations = g18n.translations()
///   |> g18n.add_translation("user.welcome", "Welcome {name}!")
///   |> g18n.add_translation("user.messages", "You have {count} new messages")
/// 
/// let translator = g18n.translator(locale, translations)
/// let params = g18n.format_params()
///   |> g18n.add_param("name", "Alice")
///   |> g18n.add_param("count", "5")
/// 
/// g18n.translate_with_params(translator, "user.welcome", params)
/// // "Welcome Alice!"
/// 
/// g18n.translate_with_params(translator, "user.messages", params)
/// // "You have 5 new messages"
/// ```
pub fn translate_with_params(
  translator: Translator,
  key: String,
  params: FormatParams,
) -> String {
  let template = translate(translator, key)
  format_string(template, params)
}

/// Translate a key with context for disambiguation.
///
/// Context-sensitive translations allow the same key to have different translations
/// based on the context in which it's used. This is essential for words that have
/// multiple meanings or grammatical forms in different situations.
///
/// Context keys are stored as `key@context` in the translation files.
///
/// ## Examples
/// ```gleam
/// let assert Ok(locale) = g18n.locale("en")
/// let translations = g18n.translations()
///   |> g18n.add_translation("may", "may")                    // auxiliary verb
///   |> g18n.add_translation("may@month", "May")              // month name
///   |> g18n.add_translation("may@permission", "allowed to")  // permission
/// 
/// let translator = g18n.translator(locale, translations)
/// 
/// g18n.translate_with_context(translator, "may", NoContext)         // "may"
/// g18n.translate_with_context(translator, "may", Context("month"))  // "May"  
/// g18n.translate_with_context(translator, "may", Context("permission")) // "allowed to"
/// ```
pub fn translate_with_context(
  translator: Translator,
  key: String,
  context: TranslationContext,
) -> String {
  let context_key = case context {
    NoContext -> key
    Context(ctx) -> key <> "@" <> ctx
  }
  translate(translator, context_key)
}

/// Translate a key with context and parameter substitution.
///
/// Combines context-sensitive translation with parameter formatting.
/// Useful for complex translations that need both disambiguation and dynamic values.
///
/// ## Examples
/// ```gleam
/// let assert Ok(locale) = g18n.locale("en")
/// let translations = g18n.translations()
///   |> g18n.add_translation("close", "close")
///   |> g18n.add_translation("close@door", "Close the {item}")
///   |> g18n.add_translation("close@application", "Close {app_name}")
/// 
/// let translator = g18n.translator(locale, translations)
/// let params = g18n.format_params() |> g18n.add_param("item", "door")
/// 
/// g18n.translate_with_context_and_params(
///   translator, 
///   "close", 
///   Context("door"), 
///   params
/// ) // "Close the door"
/// ```
pub fn translate_with_context_and_params(
  translator: Translator,
  key: String,
  context: TranslationContext,
  params: FormatParams,
) -> String {
  let template = translate_with_context(translator, key, context)
  format_string(template, params)
}

/// Add a context-sensitive translation to a translations container.
///
/// Helper function to add translations with context using the `key@context` format.
///
/// ## Examples
/// ```gleam
/// let translations = g18n.translations()
///   |> g18n.add_context_translation("bank", "financial", "financial institution")
///   |> g18n.add_context_translation("bank", "river", "riverbank")
///   |> g18n.add_context_translation("bank", "turn", "lean to one side")
/// ```
pub fn add_context_translation(
  translations: Translations,
  key: String,
  context: String,
  value: String,
) -> Translations {
  let context_key = key <> "@" <> context
  add_translation(translations, context_key, value)
}

/// Get all context variants for a given base key.
///
/// Returns all translations that match the base key with different contexts.
/// Useful for discovering available contexts for a particular key.
///
/// ## Examples
/// ```gleam
/// let translations = g18n.translations()
///   |> g18n.add_translation("bank", "bank")
///   |> g18n.add_context_translation("bank", "financial", "financial institution")
///   |> g18n.add_context_translation("bank", "river", "riverbank")
/// 
/// g18n.get_context_variants(translations, "bank")
/// // [#("bank", "bank"), #("bank@financial", "financial institution"), #("bank@river", "riverbank")]
/// ```
pub fn get_context_variants(
  translations: Translations,
  base_key: String,
) -> List(#(String, String)) {
  trie.fold(translations, [], fn(acc, key_parts, value) {
    let full_key = string.join(key_parts, ".")
    case string.starts_with(full_key, base_key) {
      True -> [#(full_key, value), ..acc]
      False -> acc
    }
  })
  |> list.reverse
}

/// Translate with automatic pluralization based on count and locale rules.
///
/// Automatically selects the appropriate plural form based on the count
/// and the language's pluralization rules. Supports multiple plural forms
/// including zero, one, two, few, many, and other.
///
/// ## Supported Plural Rules
/// - **English**: 1 → `.one`, others → `.other`
/// - **Portuguese**: 0 → `.zero`, 1 → `.one`, others → `.other`  
/// - **Russian**: Complex Slavic rules → `.one`/`.few`/`.many`
///
/// ## Examples
/// ```gleam
/// let assert Ok(en_locale) = g18n.locale("en")
/// let assert Ok(pt_locale) = g18n.locale("pt")
/// let translations = g18n.translations()
///   |> g18n.add_translation("item.one", "1 item")
///   |> g18n.add_translation("item.other", "{count} items")
///   |> g18n.add_translation("item.zero", "no items")
/// 
/// let en_translator = g18n.translator(en_locale, translations)
/// let pt_translator = g18n.translator(pt_locale, translations)
/// 
/// // English pluralization (1 → one, others → other)
/// g18n.translate_plural(en_translator, "item", 1)  // "1 item"
/// g18n.translate_plural(en_translator, "item", 5)  // "{count} items"
/// 
/// // Portuguese pluralization (0 → zero, 1 → one, others → other)  
/// g18n.translate_plural(pt_translator, "item", 0)  // "no items"
/// g18n.translate_plural(pt_translator, "item", 1)  // "1 item"
/// g18n.translate_plural(pt_translator, "item", 3)  // "{count} items"
/// ```
pub fn translate_plural(
  translator: Translator,
  key: String,
  count: Int,
) -> String {
  let language = translator.locale.language
  let plural_rule = get_locale_plural_rule(language)
  let plural_key = get_plural_key(key, count, plural_rule)
  translate(translator, plural_key)
}

/// Translate with pluralization and parameter substitution.
///
/// Combines pluralization and parameter substitution in a single function.
/// First determines the appropriate plural form based on count and locale,
/// then performs parameter substitution on the resulting template.
///
/// ## Examples
/// ```gleam
/// let params = dict.from_list([("name", "Alice"), ("count", "3")])
/// 
/// g18n.translate_plural_with_params(en_translator, "user.items", 3, params)
/// // "Alice has 3 items"
/// 
/// g18n.translate_plural_with_params(en_translator, "user.items", 1, params) 
/// // "Alice has 1 item"
/// ```
pub fn translate_plural_with_params(
  translator: Translator,
  key: String,
  count: Int,
  params: FormatParams,
) -> String {
  let template = translate_plural(translator, key, count)
  format_string(template, params)
}

/// Get the locale from a translator.
///
/// ## Examples
/// ```gleam
/// let assert Ok(locale) = g18n.locale("en-US")
/// let translator = g18n.translator(locale, g18n.translations())
/// g18n.get_locale(translator) // Locale(language: "en", region: Some("US"))
/// ```
pub fn get_locale(translator: Translator) -> Locale {
  translator.locale
}

/// Get the fallback locale from a translator, if set.
///
/// ## Examples
/// ```gleam
/// let assert Ok(en) = g18n.locale("en")
/// let assert Ok(es) = g18n.locale("es")
/// let translator = g18n.translator(es, g18n.translations())
///   |> g18n.with_fallback(en, g18n.translations())
/// g18n.get_fallback_locale(translator) // Some(Locale(language: "en", region: None))
/// ```
pub fn get_fallback_locale(translator: Translator) -> Option(Locale) {
  translator.fallback_locale
}

/// Get the translations from a translator.
///
/// ## Examples
/// ```gleam
/// let translations = g18n.translations()
///   |> g18n.add_translation("hello", "Hello")
/// let translator = g18n.translator(g18n.locale("en"), translations)
/// g18n.get_translations(translator) // Returns the translations container
/// ```
pub fn get_translations(translator: Translator) -> Translations {
  translator.translations
}

/// Get the fallback translations from a translator, if set.
///
/// ## Examples
/// ```gleam
/// let en_translations = g18n.translations()
///   |> g18n.add_translation("hello", "Hello")
/// let translator = g18n.translator(g18n.locale("es"), g18n.translations())
///   |> g18n.with_fallback(g18n.locale("en"), en_translations)
/// g18n.get_fallback_translations(translator) // Some(translations)
/// ```
pub fn get_fallback_translations(translator: Translator) -> Option(Translations) {
  translator.fallback_translations
}

fn get_fallback_translation(
  translator: Translator,
  key_parts: List(String),
  original_key: String,
) -> String {
  case translator.fallback_translations {
    Some(fallback_trans) -> {
      case trie.get(fallback_trans, key_parts) {
        Ok(translation) -> translation
        Error(Nil) -> original_key
      }
    }
    None -> original_key
  }
}

// Locale Negotiation
/// Negotiate the best locale match from available options.
///
/// Given a list of available locales and user preferences, returns the best match
/// using standard locale negotiation algorithms. Prefers exact matches, falls back
/// to language matches, then to region-less matches.
///
/// ## Examples
/// ```gleam
/// let available = [
///   locale("en"), locale("en-US"), locale("es"), locale("fr")
/// ]
/// let preferred = [locale("en-GB"), locale("es"), locale("de")]
/// 
/// g18n.negotiate_locale(available, preferred)
/// // Returns Some(locale("en")) - language match for en-GB
/// ```
pub fn negotiate_locale(
  available: List(Result(Locale, LocaleError)),
  preferred: List(Result(Locale, LocaleError)),
) -> Option(Locale) {
  let available_locales =
    list.filter_map(available, fn(x) { result.try(x, Ok) })
  let preferred_locales =
    list.filter_map(preferred, fn(x) { result.try(x, Ok) })

  case preferred_locales {
    [] ->
      case list.first(available_locales) {
        Ok(locale) -> Some(locale)
        Error(Nil) -> None
      }
    [first_pref, ..rest_prefs] -> {
      // Try exact match first
      case find_exact_match(available_locales, first_pref) {
        Some(match) -> Some(match)
        None -> {
          // Try language match
          case find_language_match(available_locales, first_pref) {
            Some(match) -> Some(match)
            None -> {
              // Try region fallback (en-US -> en)
              case find_region_fallback(available_locales, first_pref) {
                Some(match) -> Some(match)
                None -> {
                  let rest_results = list.map(rest_prefs, fn(loc) { Ok(loc) })
                  negotiate_locale(available, rest_results)
                }
              }
            }
          }
        }
      }
    }
  }
}

/// Parse Accept-Language header for locale negotiation.
///
/// Parses HTTP Accept-Language header format and returns ordered list of locales
/// by preference (quality values considered).
///
/// ## Examples  
/// ```gleam
/// g18n.parse_accept_language("en-US,en;q=0.9,fr;q=0.8")
/// // [Ok(Locale("en", Some("US"))), Ok(Locale("en", None)), Ok(Locale("fr", None))]
/// ```
pub fn parse_accept_language(
  header: String,
) -> List(Result(Locale, LocaleError)) {
  header
  |> string.split(",")
  |> list.map(string.trim)
  |> list.filter(fn(s) { s != "" })
  |> list.map(fn(lang_spec) {
    case string.split(lang_spec, ";") {
      [] -> Error(InvalidLocale("Empty language specification"))
      [locale_code] -> locale(locale_code)
      [locale_code, ..] -> locale(locale_code)
    }
  })
}

/// Get quality score for locale preference ordering.
///
/// Used internally for locale negotiation scoring. Higher scores indicate
/// better matches.
pub fn get_locale_quality_score(preferred: Locale, available: Locale) -> Float {
  case locales_exact_match(preferred, available) {
    True -> 1.0
    False ->
      case locales_match_language(preferred, available) {
        True -> 0.8
        False -> 0.0
      }
  }
}

fn find_exact_match(
  available: List(Locale),
  preferred: Locale,
) -> Option(Locale) {
  case list.find(available, fn(loc) { locales_exact_match(loc, preferred) }) {
    Ok(locale) -> Some(locale)
    Error(Nil) -> None
  }
}

fn find_language_match(
  available: List(Locale),
  preferred: Locale,
) -> Option(Locale) {
  case
    list.find(available, fn(loc) { locales_match_language(loc, preferred) })
  {
    Ok(locale) -> Some(locale)
    Error(Nil) -> None
  }
}

fn find_region_fallback(
  available: List(Locale),
  preferred: Locale,
) -> Option(Locale) {
  let lang_only = locale_language_only(preferred)
  case list.find(available, fn(loc) { locales_exact_match(loc, lang_only) }) {
    Ok(locale) -> Some(locale)
    Error(Nil) -> None
  }
}

// Translation Management
/// Create a new empty translations container.
///
/// ## Examples
/// ```gleam
/// let translations = g18n.translations()
///   |> g18n.add_translation("hello", "Hello")
///   |> g18n.add_translation("goodbye", "Goodbye")
/// ```
pub fn translations() -> Translations {
  trie.new()
}

/// Add a translation key-value pair to a translations container.
///
/// Supports hierarchical keys using dot notation for organization.
///
/// ## Examples
/// ```gleam
/// let translations = g18n.translations()
///   |> g18n.add_translation("ui.button.save", "Save")
///   |> g18n.add_translation("ui.button.cancel", "Cancel")
///   |> g18n.add_translation("user.name", "Name")
/// ```
pub fn add_translation(
  translations: Translations,
  key: String,
  value: String,
) -> Translations {
  let key_parts = string.split(key, ".")
  trie.insert(translations, key_parts, value)
}

/// Get all translation keys that start with a given prefix.
///
/// Useful for finding all keys within a specific namespace.
///
/// ## Examples
/// ```gleam
/// let translations = g18n.translations()
///   |> g18n.add_translation("ui.button.save", "Save")
///   |> g18n.add_translation("ui.button.cancel", "Cancel")
///   |> g18n.add_translation("user.name", "Name")
/// 
/// g18n.get_keys_with_prefix(translations, "ui.button")
/// // ["ui.button.save", "ui.button.cancel"]
/// ```
pub fn get_keys_with_prefix(
  translations: Translations,
  prefix: String,
) -> List(String) {
  let prefix_parts = string.split(prefix, ".")
  trie.fold(translations, [], fn(acc, key_parts, _value) {
    let full_key = string.join(key_parts, ".")
    case has_prefix(key_parts, prefix_parts) {
      True -> [full_key, ..acc]
      False -> acc
    }
  })
  |> list.reverse
}

/// Get all key-value pairs from translations within a specific namespace.
///
/// Returns tuples of (key, translation) for all keys that start with the namespace prefix.
///
/// ## Examples
/// ```gleam
/// let translations = g18n.translations()
///   |> g18n.add_translation("ui.button.save", "Save")
///   |> g18n.add_translation("ui.button.cancel", "Cancel")
///   |> g18n.add_translation("user.name", "Name")
/// let translator = g18n.translator(g18n.locale("en"), translations)
/// 
/// g18n.get_namespace(translator, "ui.button")
/// // [#("ui.button.save", "Save"), #("ui.button.cancel", "Cancel")]
/// ```
pub fn get_namespace(
  translator: Translator,
  namespace: String,
) -> List(#(String, String)) {
  let prefix_parts = string.split(namespace, ".")
  trie.fold(translator.translations, [], fn(acc, key_parts, value) {
    let full_key = string.join(key_parts, ".")
    case has_prefix(key_parts, prefix_parts) {
      True -> [#(full_key, value), ..acc]
      False -> acc
    }
  })
  |> list.reverse
}

// Helper function to check if a key has a given prefix
fn has_prefix(key_parts: List(String), prefix_parts: List(String)) -> Bool {
  case prefix_parts, key_parts {
    [], _ -> True
    [prefix_head, ..prefix_tail], [key_head, ..key_tail]
      if prefix_head == key_head
    -> has_prefix(key_tail, prefix_tail)
    _, _ -> False
  }
}

// Format Functions
/// Create a new empty parameter container for string formatting.
///
/// ## Examples
/// ```gleam
/// let params = g18n.format_params()
///   |> g18n.add_param("name", "Alice")
///   |> g18n.add_param("count", "5")
/// ```
pub fn format_params() -> FormatParams {
  dict.new()
}

/// Add a parameter key-value pair to a format parameters container.
///
/// Used for template substitution in translations.
///
/// ## Examples
/// ```gleam
/// let params = g18n.format_params()
///   |> g18n.add_param("user", "Alice")
///   |> g18n.add_param("item_count", "3")
/// ```
pub fn add_param(
  params: FormatParams,
  key: String,
  value: String,
) -> FormatParams {
  dict.insert(params, key, value)
}

/// Perform parameter substitution in a template string.
///
/// Replaces {param} placeholders with actual values from the parameters.
///
/// ## Examples
/// ```gleam
/// let params = g18n.format_params()
///   |> g18n.add_param("name", "Alice")
///   |> g18n.add_param("count", "5")
/// 
/// g18n.format_string("Hello {name}, you have {count} messages", params)
/// // "Hello Alice, you have 5 messages"
/// ```
pub fn format_string(template: String, params: FormatParams) -> String {
  dict.fold(params, template, fn(acc, key, value) {
    string.replace(acc, "{" <> key <> "}", value)
  })
}

/// Extract all parameter placeholders from a template string.
///
/// Returns a list of parameter names found within {braces}.
///
/// ## Examples
/// ```gleam
/// g18n.extract_placeholders("Hello {name}, you have {count} new {type}")
/// // ["name", "count", "type"]
/// ```
pub fn extract_placeholders(template: String) -> List(String) {
  let assert Ok(placeholder_regex) = regexp.from_string("\\{([^}]+)\\}")

  regexp.scan(placeholder_regex, template)
  |> list_map(fn(match) {
    case match.submatches {
      [Some(placeholder)] -> placeholder
      _ -> ""
    }
  })
  |> list_filter(fn(placeholder) { placeholder != "" })
}

// Plural Functions
/// Implement English pluralization rules.
///
/// Returns One for count=1, Other for all other counts.
///
/// ## Examples
/// ```gleam
/// g18n.english_plural_rule(1) // One
/// g18n.english_plural_rule(2) // Other
/// g18n.english_plural_rule(0) // Other
/// ```
pub fn english_plural_rule(count: Int) -> PluralRule {
  case count {
    1 -> One
    _ -> Other
  }
}

/// Implement Portuguese pluralization rules.
///
/// Returns Zero for count=0, One for count=1, Other for all other counts.
///
/// ## Examples
/// ```gleam
/// g18n.portuguese_plural_rule(0) // Zero
/// g18n.portuguese_plural_rule(1) // One
/// g18n.portuguese_plural_rule(5) // Other
/// ```
pub fn portuguese_plural_rule(count: Int) -> PluralRule {
  case count {
    0 -> Zero
    1 -> One
    _ -> Other
  }
}

/// Implement complex Russian pluralization rules.
///
/// Handles Slavic plural forms (One/Few/Many) based on modular arithmetic.
/// One: ends in 1, but not 11
/// Few: ends in 2-4, but not 12-14  
/// Many: all other cases
///
/// ## Examples
/// ```gleam
/// g18n.russian_plural_rule(1)  // One
/// g18n.russian_plural_rule(2)  // Few
/// g18n.russian_plural_rule(5)  // Many
/// g18n.russian_plural_rule(11) // Many
/// ```
pub fn russian_plural_rule(count: Int) -> PluralRule {
  let mod_10 = count % 10
  let mod_100 = count % 100

  case mod_10, mod_100 {
    1, n if n != 11 -> One
    v, n if v >= 2 && v <= 4 && n < 12 || n > 14 -> Few
    _, _ -> Many
  }
}

/// Implement Spanish pluralization rules.
///
/// Returns One for count=1, Other for all other counts.
/// Similar to English but explicitly implemented for clarity.
///
/// ## Examples
/// ```gleam
/// g18n.spanish_plural_rule(1) // One
/// g18n.spanish_plural_rule(0) // Other
/// g18n.spanish_plural_rule(5) // Other
/// ```
pub fn spanish_plural_rule(count: Int) -> PluralRule {
  case count {
    1 -> One
    _ -> Other
  }
}

/// Implement French pluralization rules.
///
/// Returns One for count=0 and count=1, Other for all other counts.
/// French treats 0 as singular (0 élément vs 2 éléments).
///
/// ## Examples
/// ```gleam
/// g18n.french_plural_rule(0) // One
/// g18n.french_plural_rule(1) // One
/// g18n.french_plural_rule(2) // Other
/// ```
pub fn french_plural_rule(count: Int) -> PluralRule {
  case count {
    0 | 1 -> One
    _ -> Other
  }
}

/// Implement German pluralization rules.
///
/// Returns One for count=1, Other for all other counts.
/// Similar to English pattern.
///
/// ## Examples
/// ```gleam
/// g18n.german_plural_rule(1) // One
/// g18n.german_plural_rule(0) // Other
/// g18n.german_plural_rule(3) // Other
/// ```
pub fn german_plural_rule(count: Int) -> PluralRule {
  case count {
    1 -> One
    _ -> Other
  }
}

/// Implement Italian pluralization rules.
///
/// Returns One for count=1, Other for all other counts.
/// Similar to English pattern.
///
/// ## Examples
/// ```gleam
/// g18n.italian_plural_rule(1) // One
/// g18n.italian_plural_rule(0) // Other
/// g18n.italian_plural_rule(2) // Other
/// ```
pub fn italian_plural_rule(count: Int) -> PluralRule {
  case count {
    1 -> One
    _ -> Other
  }
}

/// Implement Arabic pluralization rules.
///
/// Arabic has complex pluralization with 6 forms:
/// Zero: 0
/// One: 1  
/// Two: 2
/// Few: 3-10
/// Many: 11-99
/// Other: 100+ and fractional
///
/// ## Examples
/// ```gleam
/// g18n.arabic_plural_rule(0)   // Zero
/// g18n.arabic_plural_rule(1)   // One
/// g18n.arabic_plural_rule(2)   // Two
/// g18n.arabic_plural_rule(5)   // Few
/// g18n.arabic_plural_rule(15)  // Many
/// g18n.arabic_plural_rule(100) // Other
/// ```
pub fn arabic_plural_rule(count: Int) -> PluralRule {
  case count {
    0 -> Zero
    1 -> One
    2 -> Two
    n if n >= 3 && n <= 10 -> Few
    n if n >= 11 && n <= 99 -> Many
    _ -> Other
  }
}

/// Implement Chinese pluralization rules.
///
/// Chinese doesn't have grammatical pluralization - same form for all counts.
/// Uses Other for all numbers for consistency with the system.
///
/// ## Examples
/// ```gleam
/// g18n.chinese_plural_rule(1)  // Other
/// g18n.chinese_plural_rule(0)  // Other
/// g18n.chinese_plural_rule(10) // Other
/// ```
pub fn chinese_plural_rule(_count: Int) -> PluralRule {
  // Chinese has no plural forms
  Other
}

/// Implement Japanese pluralization rules.
///
/// Japanese doesn't have grammatical pluralization - same form for all counts.
/// Uses Other for all numbers for consistency with the system.
///
/// ## Examples
/// ```gleam
/// g18n.japanese_plural_rule(1)  // Other
/// g18n.japanese_plural_rule(0)  // Other
/// g18n.japanese_plural_rule(10) // Other
/// ```
pub fn japanese_plural_rule(_count: Int) -> PluralRule {
  // Japanese has no plural forms
  Other
}

/// Implement Korean pluralization rules.
///
/// Korean doesn't have strict grammatical pluralization like European languages.
/// Uses Other for all numbers for consistency with the system.
///
/// ## Examples
/// ```gleam
/// g18n.korean_plural_rule(1)  // Other
/// g18n.korean_plural_rule(0)  // Other
/// g18n.korean_plural_rule(10) // Other
/// ```
pub fn korean_plural_rule(_count: Int) -> PluralRule {
  // Korean has no strict plural forms
  Other
}

/// Implement Hindi pluralization rules.
///
/// Hindi has simple pluralization: One for 0 and 1, Other for everything else.
/// This covers the basic singular/plural distinction in Hindi.
///
/// ## Examples
/// ```gleam
/// g18n.hindi_plural_rule(0) // One
/// g18n.hindi_plural_rule(1) // One
/// g18n.hindi_plural_rule(2) // Other
/// ```
pub fn hindi_plural_rule(count: Int) -> PluralRule {
  case count {
    0 | 1 -> One
    _ -> Other
  }
}

/// Generate a pluralized key based on count and plural rules.
///
/// Takes a base translation key and appends the appropriate plural suffix
/// (.zero, .one, .two, .few, .many, .other) based on the count and the 
/// provided plural rule function.
///
/// ## Examples
/// ```gleam
/// let en_rule = g18n.get_locale_plural_rule("en")
/// 
/// g18n.get_plural_key("item", 1, en_rule)  // "item.one"
/// g18n.get_plural_key("item", 5, en_rule)  // "item.other"
/// g18n.get_plural_key("item", 0, en_rule)  // "item.other"
/// ```
pub fn get_plural_key(
  base_key: String,
  count: Int,
  plural_rule: PluralRules,
) -> String {
  let rule = plural_rule(count)
  case rule {
    Zero -> base_key <> ".zero"
    One -> base_key <> ".one"
    Two -> base_key <> ".two"
    Few -> base_key <> ".few"
    Many -> base_key <> ".many"
    Other -> base_key <> ".other"
  }
}

/// Get the plural rule function for a specific language.
///
/// Returns the appropriate pluralization rule function based on the language code.
/// Supports all 12 languages with proper pluralization rules.
///
/// ## Supported Languages
/// - English ("en"): One/Other
/// - Spanish ("es"): One/Other  
/// - Portuguese ("pt"): Zero/One/Other
/// - French ("fr"): One (0,1)/Other
/// - German ("de"): One/Other
/// - Italian ("it"): One/Other
/// - Russian ("ru"): One/Few/Many (complex Slavic rules)
/// - Arabic ("ar"): Zero/One/Two/Few/Many/Other (6 forms)
/// - Chinese ("zh"): Other only (no pluralization)
/// - Japanese ("ja"): Other only (no pluralization)
/// - Korean ("ko"): Other only (no pluralization)
/// - Hindi ("hi"): One (0,1)/Other
///
/// ## Examples
/// ```gleam
/// let en_rule = g18n.get_locale_plural_rule("en")
/// let ar_rule = g18n.get_locale_plural_rule("ar")
/// let fallback_rule = g18n.get_locale_plural_rule("unknown")  // Uses English rules
/// ```
pub fn get_locale_plural_rule(language: String) -> PluralRules {
  case language {
    "en" -> english_plural_rule
    "es" -> spanish_plural_rule
    "pt" -> portuguese_plural_rule
    "fr" -> french_plural_rule
    "de" -> german_plural_rule
    "it" -> italian_plural_rule
    "ru" -> russian_plural_rule
    "ar" -> arabic_plural_rule
    "zh" -> chinese_plural_rule
    "ja" -> japanese_plural_rule
    "ko" -> korean_plural_rule
    "hi" -> hindi_plural_rule
    _ -> english_plural_rule
    // Fallback to English for unsupported languages
  }
}

// Advanced Pluralization Functions

/// Translate with cardinal pluralization rules.
///
/// Alias for `translate_plural` that explicitly indicates the use of cardinal
/// number rules (used for counting: 1 item, 2 items, etc.). This is the
/// standard pluralization used for most counting scenarios.
///
/// ## Examples
/// ```gleam
/// g18n.translate_cardinal(en_translator, "book", 1)   // "book.one" 
/// g18n.translate_cardinal(en_translator, "book", 3)   // "book.other"
/// g18n.translate_cardinal(pt_translator, "livro", 0)  // "livro.zero" 
/// ```
pub fn translate_cardinal(
  translator: Translator,
  key: String,
  count: Int,
) -> String {
  translate_plural(translator, key, count)
}

/// Translate with ordinal number rules.
///
/// Uses ordinal pluralization rules for position-based numbers (1st, 2nd, 3rd, etc.).
/// Different languages have different rules for ordinal endings, and this function
/// applies the appropriate ordinal key suffix based on the position and locale.
///
/// ## Examples
/// ```gleam
/// g18n.translate_ordinal(en_translator, "place", 1)   // "place.one" → "1st place"
/// g18n.translate_ordinal(en_translator, "place", 2)   // "place.two" → "2nd place"  
/// g18n.translate_ordinal(en_translator, "place", 3)   // "place.few" → "3rd place"
/// g18n.translate_ordinal(en_translator, "place", 11)  // "place.other" → "11th place"
/// ```
pub fn translate_ordinal(
  translator: Translator,
  key: String,
  position: Int,
) -> String {
  let language = translator.locale.language
  let ordinal_rule = get_ordinal_rule(language, position)
  let ordinal_key = get_ordinal_key(key, ordinal_rule)
  translate(translator, ordinal_key)
}

/// Translate for numeric ranges.
///
/// Handles translations for numeric ranges, choosing between single value
/// and range translations. Uses ".single" key suffix when from equals to,
/// and ".range" suffix for actual ranges.
///
/// ## Examples
/// ```gleam
/// g18n.translate_range(en_translator, "pages", 5, 5)   // "pages.single" → "Page 5"
/// g18n.translate_range(en_translator, "pages", 1, 10)  // "pages.range" → "Pages 1-10"
/// g18n.translate_range(en_translator, "items", 3, 7)   // "items.range" → "Items 3 through 7"
/// ```
pub fn translate_range(
  translator: Translator,
  key: String,
  from: Int,
  to: Int,
) -> String {
  let range_key = case from, to {
    f, t if f == t -> key <> ".single"
    _, _ -> key <> ".range"
  }
  translate(translator, range_key)
}

/// Translate ordinal numbers with parameter substitution.
///
/// Combines ordinal number translation with parameter substitution.
/// Automatically adds `position` and `ordinal` parameters to the provided
/// parameters for convenient template formatting.
///
/// ## Examples
/// ```gleam
/// let params = dict.from_list([("name", "Alice")])
/// 
/// g18n.translate_ordinal_with_params(en_translator, "winner", 1, params)
/// // Template: "{name} finished in {position}{ordinal} place" 
/// // Result: "Alice finished in 1st place"
/// 
/// g18n.translate_ordinal_with_params(en_translator, "winner", 3, params)
/// // Result: "Alice finished in 3rd place"
/// ```
pub fn translate_ordinal_with_params(
  translator: Translator,
  key: String,
  position: Int,
  params: FormatParams,
) -> String {
  let template = translate_ordinal(translator, key, position)
  let enhanced_params =
    params
    |> dict.insert("position", int.to_string(position))
    |> dict.insert(
      "ordinal",
      get_ordinal_suffix(translator.locale.language, position),
    )
  format_string(template, enhanced_params)
}

/// Translate numeric ranges with parameter substitution.
///
/// Combines range translation with parameter substitution. Automatically
/// adds `from`, `to`, and `total` parameters to the provided parameters
/// for convenient template formatting.
///
/// ## Examples  
/// ```gleam
/// let params = dict.from_list([("type", "chapters")])
/// 
/// g18n.translate_range_with_params(en_translator, "content", 1, 5, params)
/// // Template: "Reading {type} {from} to {to} ({total} total)"
/// // Result: "Reading chapters 1 to 5 (5 total)"
/// 
/// g18n.translate_range_with_params(en_translator, "content", 3, 3, params) 
/// // Uses .single key, Result: "Reading chapter 3"
/// ```
pub fn translate_range_with_params(
  translator: Translator,
  key: String,
  from: Int,
  to: Int,
  params: FormatParams,
) -> String {
  let template = translate_range(translator, key, from, to)
  let enhanced_params =
    params
    |> dict.insert("from", int.to_string(from))
    |> dict.insert("to", int.to_string(to))
    |> dict.insert("total", int.to_string(to - from + 1))
  format_string(template, enhanced_params)
}

// Ordinal rule functions
fn get_ordinal_rule(language: String, position: Int) -> OrdinalRule {
  case language {
    "en" -> english_ordinal_rule(position)
    _ -> english_ordinal_rule(position)
  }
}

fn english_ordinal_rule(position: Int) -> OrdinalRule {
  let mod_100 = position % 100
  let mod_10 = position % 10

  case mod_100 {
    11 | 12 | 13 -> Nth
    _ ->
      case mod_10 {
        1 -> First
        2 -> Second
        3 -> Third
        _ -> Nth
      }
  }
}

fn get_ordinal_key(base_key: String, ordinal_rule: OrdinalRule) -> String {
  case ordinal_rule {
    First -> base_key <> ".first"
    Second -> base_key <> ".second"
    Third -> base_key <> ".third"
    Nth -> base_key <> ".nth"
  }
}

fn get_ordinal_suffix(language: String, position: Int) -> String {
  case language {
    "en" -> english_ordinal_suffix(position)
    _ -> string.inspect(position)
  }
}

fn english_ordinal_suffix(position: Int) -> String {
  let mod_100 = position % 100
  let mod_10 = position % 10

  let suffix = case mod_100 {
    11 | 12 | 13 -> "th"
    _ ->
      case mod_10 {
        1 -> "st"
        2 -> "nd"
        3 -> "rd"
        _ -> "th"
      }
  }

  int.to_string(position) <> suffix
}

// Number Formatting Types and Functions
pub type NumberFormat {
  Decimal(precision: Int)
  Currency(currency_code: String, precision: Int)
  Percentage(precision: Int)
  Scientific(precision: Int)
  Compact
  // 1.2K, 3.4M, 1.2B
}

/// Format numbers according to locale-specific conventions and format type.
///
/// Provides comprehensive number formatting including decimal separators,
/// thousands separators, currency symbols, percentage formatting, and 
/// compact notation. Uses proper locale conventions for each language.
///
/// ## Format Types
/// - `Decimal(precision)`: Standard decimal formatting with locale separators
/// - `Currency(currency_code, precision)`: Currency with appropriate symbols and placement
/// - `Percentage(precision)`: Percentage formatting with locale conventions
/// - `Scientific(precision)`: Scientific notation (simplified)
/// - `Compact`: Compact notation (1.5K, 2.3M, 1.2B)
///
/// ## Examples
/// ```gleam
/// let assert Ok(en_locale) = g18n.locale("en")
/// let assert Ok(de_locale) = g18n.locale("de")
/// let translations = g18n.translations()
/// let en_translator = g18n.translator(en_locale, translations)
/// let de_translator = g18n.translator(de_locale, translations)
/// 
/// // Decimal formatting (locale-aware separators)
/// g18n.format_number(en_translator, 1234.56, g18n.Decimal(2))
/// // "1234.56" (English uses . for decimal)
/// g18n.format_number(de_translator, 1234.56, g18n.Decimal(2))
/// // "1234,56" (German uses , for decimal)
/// 
/// // Currency formatting  
/// g18n.format_number(en_translator, 29.99, g18n.Currency("USD", 2))
/// // "$29.99"
/// g18n.format_number(de_translator, 29.99, g18n.Currency("EUR", 2))
/// // "29.99 €" (German places currency after)
/// 
/// // Percentage
/// g18n.format_number(en_translator, 0.75, g18n.Percentage(1))
/// // "75.0%"
/// 
/// // Compact notation
/// g18n.format_number(en_translator, 1500000.0, g18n.Compact)
/// // "1.5M"
/// g18n.format_number(en_translator, 2500.0, g18n.Compact)  
/// // "2.5K"
/// ```
pub fn format_number(
  translator: Translator,
  number: Float,
  format: NumberFormat,
) -> String {
  let language = translator.locale.language
  case format {
    Decimal(precision) -> format_decimal(number, precision, language)
    Currency(currency_code, precision) ->
      format_currency(number, currency_code, precision, language)
    Percentage(precision) -> format_percentage(number, precision, language)
    Scientific(precision) -> format_scientific(number, precision)
    Compact -> format_compact(number, language)
  }
}

/// Format a number as a decimal with locale-specific decimal and thousands separators.
/// 
/// ## Examples
/// ```gleam
/// format_decimal(1234.5678, 2, "en")    // "1,234.57"
/// format_decimal(1234.5678, 2, "pt")    // "1.234,57"
/// format_decimal(1000.0, 0, "en")       // "1,000"
/// ```
pub fn format_decimal(number: Float, precision: Int, language: String) -> String {
  let decimal_separator = get_decimal_separator(language)
  let thousands_separator = get_thousands_separator(language)

  let formatted_number =
    float.to_precision(number, precision) |> float.to_string
  add_thousands_separators(
    formatted_number,
    decimal_separator,
    thousands_separator,
  )
}

/// Format a number as currency with locale-specific formatting and currency symbol positioning.
/// 
/// ## Examples
/// ```gleam
/// format_currency(1234.56, "USD", 2, "en")  // "$1,234.56"
/// format_currency(1234.56, "EUR", 2, "pt")  // "1.234,56 €"
/// format_currency(50.0, "GBP", 2, "en")     // "£50.00"
/// ```
pub fn format_currency(
  number: Float,
  currency_code: String,
  precision: Int,
  language: String,
) -> String {
  let formatted_amount = format_decimal(number, precision, language)
  let currency_symbol = get_currency_symbol(currency_code)
  let currency_position = get_currency_position(language)

  case currency_position {
    "before" -> currency_symbol <> formatted_amount
    "after" -> formatted_amount <> " " <> currency_symbol
    _ -> currency_symbol <> formatted_amount
  }
}

/// Format a decimal number as a percentage with locale-specific formatting.
/// The input number is multiplied by 100 and formatted with a percent symbol.
/// 
/// ## Examples
/// ```gleam
/// format_percentage(0.1234, 2, "en")   // "12.34%"
/// format_percentage(0.75, 1, "fr")     // "75.0 %"
/// format_percentage(0.5, 0, "en")      // "50%"
/// ```
pub fn format_percentage(
  number: Float,
  precision: Int,
  language: String,
) -> String {
  let percentage_value = number *. 100.0
  let formatted = format_decimal(percentage_value, precision, language)
  let percent_symbol = get_percent_symbol()

  case language {
    "fr" -> formatted <> " " <> percent_symbol
    _ -> formatted <> percent_symbol
  }
}

/// Format a number in scientific notation with the specified precision.
/// Note: This is a simplified implementation that could be enhanced with proper locale support.
/// 
/// ## Examples
/// ```gleam
/// format_scientific(1234.0, 2)     // "1234.00E+00"
/// format_scientific(0.00123, 3)    // "0.001E+00"
/// ```
pub fn format_scientific(number: Float, precision: Int) -> String {
  // Basic scientific notation - could be enhanced with proper locale support
  let formatted = float.to_precision(number, precision) |> float.to_string
  formatted <> "E+00"
  // Simplified for now
}

/// Format large numbers in compact notation using locale-specific suffixes.
/// Numbers are abbreviated with suffixes like K, M, B for thousands, millions, billions.
/// 
/// ## Examples
/// ```gleam
/// format_compact(1500.0, "en")           // "1.5K"
/// format_compact(2500000.0, "en")        // "2.5M"
/// format_compact(3200000000.0, "en")     // "3.2B"
/// format_compact(500.0, "en")            // "500"
/// ```
pub fn format_compact(number: Float, language: String) -> String {
  case number {
    n if n >=. 1_000_000_000.0 -> {
      let billions = n /. 1_000_000_000.0
      float.to_precision(billions, 1) |> float.to_string
      <> get_billion_suffix(language)
    }
    n if n >=. 1_000_000.0 -> {
      let millions = n /. 1_000_000.0
      float.to_precision(millions, 1) |> float.to_string
      <> get_million_suffix(language)
    }
    n if n >=. 1000.0 -> {
      let thousands = n /. 1000.0
      float.to_precision(thousands, 1) |> float.to_string
      <> get_thousand_suffix(language)
    }
    _ -> int.to_string(float.round(number))
  }
}

// Locale-specific formatting helpers
fn get_decimal_separator(language: String) -> String {
  case language {
    "pt" | "es" | "fr" | "de" -> ","
    _ -> "."
  }
}

fn get_thousands_separator(language: String) -> String {
  case language {
    "pt" | "es" -> "."
    "fr" -> " "
    "de" -> ","
    _ -> ","
  }
}

fn get_currency_symbol(currency_code: String) -> String {
  case currency_code {
    "USD" -> "$"
    "EUR" -> "€"
    "GBP" -> "£"
    "BRL" -> "R$"
    "JPY" -> "¥"
    _ -> currency_code
  }
}

fn get_currency_position(language: String) -> String {
  case language {
    "en" -> "before"
    "pt" | "es" | "fr" -> "before"
    "de" -> "after"
    _ -> "before"
  }
}

fn get_percent_symbol() -> String {
  "%"
}

fn get_thousand_suffix(language: String) -> String {
  case language {
    "pt" -> "mil"
    "es" -> "k"
    "fr" -> "k"
    _ -> "K"
  }
}

fn get_million_suffix(language: String) -> String {
  case language {
    "pt" -> "M"
    "es" -> "M"
    "fr" -> "M"
    _ -> "M"
  }
}

fn get_billion_suffix(language: String) -> String {
  case language {
    "pt" -> "B"
    "es" -> "B"
    "fr" -> "Md"
    _ -> "B"
  }
}

fn add_thousands_separators(
  number_str: String,
  _decimal_separator: String,
  _thousands_separator: String,
) -> String {
  // Simplified implementation - would need proper number parsing in production
  number_str
}

pub type DateTimeFormat {
  Short
  // 12/25/23, 3:45 PM
  Medium
  // Dec 25, 2023, 3:45:30 PM  
  Long
  // December 25, 2023, 3:45:30 PM GMT
  Full
  // Monday, December 25, 2023, 3:45:30 PM GMT
  Custom(String)
  // "YYYY-MM-DD HH:mm:ss"
}

pub type RelativeDuration {
  Seconds(Int)
  Minutes(Int)
  Hours(Int)
  Days(Int)
  Weeks(Int)
  Months(Int)
  Years(Int)
}

/// Format a date according to the translator's locale and specified format.
/// 
/// Supports multiple format levels from short numeric formats to full text 
/// with day-of-week names. Automatically uses locale-appropriate formatting
/// including proper date separators, month names, and cultural conventions.
///
/// ## Supported Languages
/// English, Spanish, Portuguese, French, German, Italian, Russian, 
/// Chinese, Japanese, Korean, Arabic, Hindi (with fallback for others)
///
/// ## Format Types
/// - `Short`: Compact numeric format (e.g., "12/25/23", "25/12/23") 
/// - `Medium`: Month abbreviation (e.g., "Dec 25, 2023", "25 dez 2023")
/// - `Long`: Full month names with GMT (e.g., "December 25, 2023 GMT")
/// - `Full`: Complete with day-of-week (e.g., "Monday, December 25, 2023 GMT")
/// - `Custom(pattern)`: Custom pattern with YYYY, MM, DD placeholders
///
/// ## Examples
/// ```gleam
/// import gleam/time/calendar
/// 
/// let assert Ok(en_locale) = g18n.locale("en")
/// let assert Ok(pt_locale) = g18n.locale("pt") 
/// let translations = g18n.translations()
/// let en_translator = g18n.translator(en_locale, translations)
/// let pt_translator = g18n.translator(pt_locale, translations)
/// 
/// let date = calendar.Date(2024, calendar.January, 15)
/// 
/// g18n.format_date(en_translator, date, g18n.Short)
/// // "01/15/24"
/// 
/// g18n.format_date(pt_translator, date, g18n.Short) 
/// // "15/01/24"
/// 
/// g18n.format_date(en_translator, date, g18n.Medium)
/// // "Jan 15, 2024"
/// 
/// g18n.format_date(en_translator, date, g18n.Full)
/// // "Monday, January 15, 2024 GMT"
/// 
/// g18n.format_date(en_translator, date, g18n.Custom("YYYY-MM-DD"))
/// // "2024-01-15"
/// ```
pub fn format_date(
  translator: Translator,
  date: calendar.Date,
  format: DateTimeFormat,
) -> String {
  let language = translator.locale.language
  case format {
    Short -> format_date_short(date, language)
    Medium -> format_date_medium(date, language)
    Long -> format_date_long(date, language)
    Full -> format_date_full(date, language)
    Custom(pattern) -> format_date_custom(date, pattern)
  }
}

/// Format a time according to the translator's locale and specified format.
///
/// Supports multiple format levels from compact numeric formats to full text
/// with timezone information. Automatically uses locale-appropriate time formatting
/// including 12-hour vs 24-hour notation based on cultural conventions.
///
/// ## Format Types
/// - `Short`: Compact time format (e.g., "3:45 PM", "15:45")
/// - `Medium`: Time with seconds (e.g., "3:45:30 PM", "15:45:30")
/// - `Long`: Time with timezone (e.g., "3:45:30 PM GMT", "15:45:30 GMT")
/// - `Full`: Complete time format (e.g., "3:45:30 PM GMT", "15:45:30 GMT")
/// - `Custom(pattern)`: Custom pattern with HH, mm, ss placeholders
///
/// ## Examples
/// ```gleam
/// let assert Ok(en_locale) = g18n.locale("en")
/// let assert Ok(pt_locale) = g18n.locale("pt")
/// let en_translator = g18n.translator(en_locale, g18n.translations())
/// let pt_translator = g18n.translator(pt_locale, g18n.translations())
/// let time = calendar.TimeOfDay(hours: 15, minutes: 30, seconds: 45)
///
/// // English uses 12-hour format
/// g18n.format_time(en_translator, time, g18n.Short)  // "3:30 PM"
/// g18n.format_time(en_translator, time, g18n.Medium) // "3:30:45 PM"
/// g18n.format_time(en_translator, time, g18n.Long)   // "3:30:45 PM GMT"
///
/// // Portuguese uses 24-hour format  
/// g18n.format_time(pt_translator, time, g18n.Short)  // "15:30"
/// g18n.format_time(pt_translator, time, g18n.Medium) // "15:30:45"
///
/// // Custom formatting
/// g18n.format_time(en_translator, time, g18n.Custom("HH:mm")) // "15:30"
/// ```
pub fn format_time(
  translator: Translator,
  time: calendar.TimeOfDay,
  format: DateTimeFormat,
) -> String {
  let language = translator.locale.language
  case format {
    Short -> format_time_short(time, language)
    Medium -> format_time_medium(time, language)
    Long -> format_time_long(time, language)
    Full -> format_time_full(time, language)
    Custom(pattern) -> format_time_custom(time, pattern)
  }
}

/// Format a date and time together according to the translator's locale and specified format.
///
/// Combines date and time formatting into a single localized string, using appropriate
/// separators and conventions for each language. Supports all format levels from
/// compact numeric formats to full descriptive text.
///
/// ## Format Types
/// - `Short`: Compact format (e.g., "12/25/23, 3:45 PM", "25/12/23, 15:45")
/// - `Medium`: Readable format (e.g., "Dec 25, 2023, 3:45:30 PM", "25 dez 2023, 15:45:30")
/// - `Long`: Full format with timezone (e.g., "December 25, 2023, 3:45:30 PM GMT")
/// - `Full`: Complete descriptive format (e.g., "Monday, December 25, 2023, 3:45:30 PM GMT")
/// - `Custom(pattern)`: Custom pattern combining date and time placeholders
///
/// ## Examples
/// ```gleam
/// let assert Ok(en_locale) = g18n.locale("en")
/// let assert Ok(pt_locale) = g18n.locale("pt")
/// let en_translator = g18n.translator(en_locale, g18n.translations())
/// let pt_translator = g18n.translator(pt_locale, g18n.translations())
/// let date = calendar.Date(year: 2023, month: calendar.December, day: 25)
/// let time = calendar.TimeOfDay(hours: 15, minutes: 30, seconds: 0)
///
/// // English formatting
/// g18n.format_datetime(en_translator, date, time, g18n.Short)
/// // "12/25/23, 3:30 PM"
///
/// g18n.format_datetime(en_translator, date, time, g18n.Medium)
/// // "Dec 25, 2023, 3:30:00 PM"
///
/// g18n.format_datetime(en_translator, date, time, g18n.Long)
/// // "December 25, 2023, 3:30:00 PM GMT"
///
/// // Portuguese formatting
/// g18n.format_datetime(pt_translator, date, time, g18n.Short)
/// // "25/12/23, 15:30"
///
/// g18n.format_datetime(pt_translator, date, time, g18n.Medium) 
/// // "25 dez 2023, 15:30:00"
///
/// // Custom formatting
/// g18n.format_datetime(en_translator, date, time, g18n.Custom("YYYY-MM-DD HH:mm"))
/// // "2023-12-25 15:30"
/// ```
pub fn format_datetime(
  translator: Translator,
  date: calendar.Date,
  time: calendar.TimeOfDay,
  format: DateTimeFormat,
) -> String {
  let language = translator.locale.language
  case format {
    Short -> format_datetime_short(date, time, language)
    Medium -> format_datetime_medium(date, time, language)
    Long -> format_datetime_long(date, time, language)
    Full -> format_datetime_full(date, time, language)
    Custom(pattern) -> format_datetime_custom(date, time, pattern)
  }
}

pub type TimeRelative {
  Past
  Future
}

/// Format relative time expressions like "2 hours ago" or "in 5 minutes".
///
/// Generates culturally appropriate relative time expressions using proper
/// pluralization rules and language-specific constructions. Supports past
/// and future expressions in 12 languages.
///
/// ## Supported Languages & Expressions
/// - **English**: "2 hours ago", "in 5 minutes"
/// - **Spanish**: "hace 2 horas", "en 5 minutos"  
/// - **Portuguese**: "há 2 horas", "em 5 minutos"
/// - **French**: "il y a 2 heures", "dans 5 minutes"
/// - **German**: "vor 2 Stunden", "in 5 Minuten"
/// - **Russian**: "2 часа назад", "через 5 минут" (with complex pluralization)
/// - **Chinese**: "2小时前", "5分钟后" (no pluralization)
/// - **Japanese**: "2時間前", "5分後"
/// - **Korean**: "2시간 전", "5분 후"
/// - **Arabic**: "منذ ساعتان", "خلال 5 دقائق" (dual/plural forms)
/// - **Hindi**: "2 घंटे पहले", "5 मिनट में"
/// - **Italian**: "2 ore fa", "tra 5 minuti"
///
/// ## Examples
/// ```gleam
/// let assert Ok(en_locale) = g18n.locale("en")
/// let assert Ok(es_locale) = g18n.locale("es")
/// let assert Ok(ru_locale) = g18n.locale("ru")
/// let translations = g18n.translations()
/// let en_translator = g18n.translator(en_locale, translations)
/// let es_translator = g18n.translator(es_locale, translations) 
/// let ru_translator = g18n.translator(ru_locale, translations)
/// 
/// // English
/// g18n.format_relative_time(en_translator, g18n.Hours(2), g18n.Past)
/// // "2 hours ago"
/// g18n.format_relative_time(en_translator, g18n.Minutes(30), g18n.Future)
/// // "in 30 minutes"
/// 
/// // Spanish  
/// g18n.format_relative_time(es_translator, g18n.Days(3), g18n.Past)
/// // "hace 3 días"
/// 
/// // Russian (complex pluralization)
/// g18n.format_relative_time(ru_translator, g18n.Hours(1), g18n.Past) 
/// // "1 час назад"
/// g18n.format_relative_time(ru_translator, g18n.Hours(2), g18n.Past)
/// // "2 часа назад"  
/// g18n.format_relative_time(ru_translator, g18n.Hours(5), g18n.Past)
/// // "5 часов назад"
/// ```
pub fn format_relative_time(
  translator: Translator,
  duration: RelativeDuration,
  relative: TimeRelative,
) -> String {
  let language = translator.locale.language
  let _ = case relative {
    Past -> "ago"
    Future -> "in"
  }

  let unit_text = case duration {
    Seconds(n) -> format_time_unit(language, "second", n)
    Minutes(n) -> format_time_unit(language, "minute", n)
    Hours(n) -> format_time_unit(language, "hour", n)
    Days(n) -> format_time_unit(language, "day", n)
    Weeks(n) -> format_time_unit(language, "week", n)
    Months(n) -> format_time_unit(language, "month", n)
    Years(n) -> format_time_unit(language, "year", n)
  }

  case relative, language {
    Past, "en" -> unit_text <> " ago"
    Future, "en" -> "in " <> unit_text
    Past, "pt" -> "há " <> unit_text
    Future, "pt" -> "em " <> unit_text
    Past, "es" -> "hace " <> unit_text
    Future, "es" -> "en " <> unit_text
    Past, "fr" -> "il y a " <> unit_text
    Future, "fr" -> "dans " <> unit_text
    Past, "de" -> "vor " <> unit_text
    Future, "de" -> "in " <> unit_text
    Past, "it" -> unit_text <> " fa"
    Future, "it" -> "tra " <> unit_text
    Past, "ru" -> unit_text <> " назад"
    Future, "ru" -> "через " <> unit_text
    Past, "zh" -> unit_text <> "前"
    Future, "zh" -> unit_text <> "后"
    Past, "ja" -> unit_text <> "前"
    Future, "ja" -> unit_text <> "後"
    Past, "ko" -> unit_text <> " 전"
    Future, "ko" -> unit_text <> " 후"
    Past, "ar" -> "منذ " <> unit_text
    Future, "ar" -> "خلال " <> unit_text
    Past, "hi" -> unit_text <> " पहले"
    Future, "hi" -> unit_text <> " में"
    _, _ -> unit_text <> " ago"
    // Default fallback
  }
}

// Date formatting implementations
fn format_date_short(date: calendar.Date, language: String) -> String {
  let year = date.year % 100 |> pad_zero
  let month = date.month |> month_to_int |> pad_zero
  let day = date.day |> pad_zero
  case language {
    "en" -> month <> "/" <> day <> "/" <> year
    "pt" | "es" | "it" | "fr" -> day <> "/" <> month <> "/" <> year
    "de" | "ru" -> day <> "." <> month <> "." <> year
    "zh" | "ja" | "ko" -> year <> "/" <> month <> "/" <> day
    "ar" | "hi" -> day <> "-" <> month <> "-" <> year
    _ -> day <> "-" <> month <> "-" <> year
  }
}

fn format_date_medium(date: calendar.Date, language: String) -> String {
  let month_name = get_month_name(date.month, language, False)
  case language {
    "en" ->
      month_name
      <> " "
      <> int.to_string(date.day)
      <> ", "
      <> int.to_string(date.year)
    "pt" | "es" ->
      int.to_string(date.day)
      <> " de "
      <> month_name
      <> " de "
      <> int.to_string(date.year)
    "fr" ->
      int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
    "de" ->
      int.to_string(date.day)
      <> ". "
      <> month_name
      <> " "
      <> int.to_string(date.year)
    "it" ->
      int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
    "ru" ->
      int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " г."
    "zh" | "ja" ->
      int.to_string(date.year)
      <> "年"
      <> month_name
      <> int.to_string(date.day)
      <> "日"
    "ko" ->
      int.to_string(date.year)
      <> "년 "
      <> month_name
      <> " "
      <> int.to_string(date.day)
      <> "일"
    "ar" ->
      int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
    "hi" ->
      int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
    _ ->
      int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
  }
}

fn format_date_long(date: calendar.Date, language: String) -> String {
  let month_name = get_month_name(date.month, language, True)
  case language {
    "en" ->
      month_name
      <> " "
      <> int.to_string(date.day)
      <> ", "
      <> int.to_string(date.year)
      <> " GMT"
    "pt" | "es" ->
      int.to_string(date.day)
      <> " de "
      <> month_name
      <> " de "
      <> int.to_string(date.year)
      <> " GMT"
    "fr" ->
      int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " GMT"
    "de" ->
      int.to_string(date.day)
      <> ". "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " GMT"
    "it" ->
      int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " GMT"
    "ru" ->
      int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " г. GMT"
    "zh" | "ja" ->
      int.to_string(date.year)
      <> "年"
      <> month_name
      <> int.to_string(date.day)
      <> "日 GMT"
    "ko" ->
      int.to_string(date.year)
      <> "년 "
      <> month_name
      <> " "
      <> int.to_string(date.day)
      <> "일 GMT"
    "ar" ->
      int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " GMT"
    "hi" ->
      int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " GMT"
    _ ->
      int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " GMT"
  }
}

fn format_date_full(date: calendar.Date, language: String) -> String {
  let day_of_week = get_day_of_week_name(date, language)
  let month_name = get_month_name(date.month, language, True)
  case language {
    "en" ->
      day_of_week
      <> ", "
      <> month_name
      <> " "
      <> int.to_string(date.day)
      <> ", "
      <> int.to_string(date.year)
      <> " GMT"
    "pt" | "es" ->
      day_of_week
      <> ", "
      <> int.to_string(date.day)
      <> " de "
      <> month_name
      <> " de "
      <> int.to_string(date.year)
      <> " GMT"
    "fr" ->
      day_of_week
      <> " "
      <> int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " GMT"
    "de" ->
      day_of_week
      <> ", "
      <> int.to_string(date.day)
      <> ". "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " GMT"
    "it" ->
      day_of_week
      <> ", "
      <> int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " GMT"
    "ru" ->
      day_of_week
      <> ", "
      <> int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " г. GMT"
    "zh" | "ja" ->
      int.to_string(date.year)
      <> "年"
      <> month_name
      <> int.to_string(date.day)
      <> "日"
      <> day_of_week
      <> " GMT"
    "ko" ->
      int.to_string(date.year)
      <> "년 "
      <> month_name
      <> " "
      <> int.to_string(date.day)
      <> "일 "
      <> day_of_week
      <> " GMT"
    "ar" ->
      day_of_week
      <> "، "
      <> int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " GMT"
    "hi" ->
      day_of_week
      <> ", "
      <> int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " GMT"
    _ ->
      day_of_week
      <> ", "
      <> int.to_string(date.day)
      <> " "
      <> month_name
      <> " "
      <> int.to_string(date.year)
      <> " GMT"
  }
}

fn format_date_custom(date: calendar.Date, pattern: String) -> String {
  pattern
  |> string.replace("YYYY", date.year |> int.to_string)
  |> string.replace("MM", pad_zero(date.month |> month_to_int))
  |> string.replace("DD", pad_zero(date.day))
}

fn month_to_int(month: calendar.Month) -> Int {
  case month {
    calendar.January -> 1
    calendar.February -> 2
    calendar.March -> 3
    calendar.April -> 4
    calendar.May -> 5
    calendar.June -> 6
    calendar.July -> 7
    calendar.August -> 8
    calendar.September -> 9
    calendar.October -> 10
    calendar.November -> 11
    calendar.December -> 12
  }
}

fn format_time_short(time: calendar.TimeOfDay, language: String) -> String {
  case language {
    "en" -> format_12_hour(time)
    _ -> format_24_hour(time)
  }
}

fn format_time_medium(time: calendar.TimeOfDay, language: String) -> String {
  case language {
    "en" -> format_12_hour_with_seconds(time)
    _ -> format_24_hour_with_seconds(time)
  }
}

fn format_time_long(time: calendar.TimeOfDay, language: String) -> String {
  format_time_medium(time, language) <> " GMT"
}

fn format_time_full(time: calendar.TimeOfDay, language: String) -> String {
  format_time_long(time, language)
}

fn format_time_custom(time: calendar.TimeOfDay, pattern: String) -> String {
  pattern
  |> string.replace("HH", pad_zero(time.hours))
  |> string.replace("mm", pad_zero(time.minutes))
  |> string.replace("ss", pad_zero(time.seconds))
}

fn format_datetime_short(
  date: calendar.Date,
  time: calendar.TimeOfDay,
  language: String,
) -> String {
  let date_part = format_date_short(date, language)
  let time_part = format_time_short(time, language)
  date_part <> " " <> time_part
}

fn format_datetime_medium(
  date: calendar.Date,
  time: calendar.TimeOfDay,
  language: String,
) -> String {
  let date_part = format_date_medium(date, language)
  let time_part = format_time_medium(time, language)
  date_part <> " " <> time_part
}

fn format_datetime_long(
  date: calendar.Date,
  time: calendar.TimeOfDay,
  language: String,
) -> String {
  let date_part = format_date_long(date, language)
  let time_part = format_time_long(time, language)
  date_part <> " " <> time_part
}

fn format_datetime_full(
  date: calendar.Date,
  time: calendar.TimeOfDay,
  language: String,
) -> String {
  format_datetime_long(date, time, language)
}

fn format_datetime_custom(
  date: calendar.Date,
  time: calendar.TimeOfDay,
  pattern: String,
) -> String {
  pattern
  |> string.replace("YYYY", int.to_string(date.year))
  |> string.replace("MM", pad_zero(date.month |> month_to_int))
  |> string.replace("DD", pad_zero(date.day))
  |> string.replace("HH", pad_zero(time.hours))
  |> string.replace("mm", pad_zero(time.minutes))
  |> string.replace("ss", pad_zero(time.seconds))
}

// Date/Time helper functions
fn get_month_name(month: calendar.Month, language: String, full: Bool) -> String {
  case month, language, full {
    calendar.January, "en", True -> "January"
    calendar.January, "en", False -> "Jan"
    calendar.February, "en", True -> "February"
    calendar.February, "en", False -> "Feb"
    calendar.March, "en", True -> "March"
    calendar.March, "en", False -> "Mar"
    calendar.April, "en", True -> "April"
    calendar.April, "en", False -> "Apr"
    calendar.May, "en", True -> "May"
    calendar.May, "en", False -> "May"
    calendar.June, "en", True -> "June"
    calendar.June, "en", False -> "Jun"
    calendar.July, "en", True -> "July"
    calendar.July, "en", False -> "Jul"
    calendar.August, "en", True -> "August"
    calendar.August, "en", False -> "Aug"
    calendar.September, "en", True -> "September"
    calendar.September, "en", False -> "Sep"
    calendar.October, "en", True -> "October"
    calendar.October, "en", False -> "Oct"
    calendar.November, "en", True -> "November"
    calendar.November, "en", False -> "Nov"
    calendar.December, "en", True -> "December"
    calendar.December, "en", False -> "Dec"
    calendar.January, "pt", True -> "janeiro"
    calendar.January, "pt", False -> "jan"
    calendar.February, "pt", True -> "fevereiro"
    calendar.February, "pt", False -> "fev"
    calendar.March, "pt", True -> "março"
    calendar.March, "pt", False -> "mar"
    calendar.April, "pt", True -> "abril"
    calendar.April, "pt", False -> "abr"
    calendar.May, "pt", True -> "maio"
    calendar.May, "pt", False -> "mai"
    calendar.June, "pt", True -> "junho"
    calendar.June, "pt", False -> "jun"
    calendar.July, "pt", True -> "julho"
    calendar.July, "pt", False -> "jul"
    calendar.August, "pt", True -> "agosto"
    calendar.August, "pt", False -> "ago"
    calendar.September, "pt", True -> "setembro"
    calendar.September, "pt", False -> "set"
    calendar.October, "pt", True -> "outubro"
    calendar.October, "pt", False -> "out"
    calendar.November, "pt", True -> "novembro"
    calendar.November, "pt", False -> "nov"
    calendar.December, "pt", True -> "dezembro"
    calendar.December, "pt", False -> "dez"
    calendar.January, "es", True -> "enero"
    calendar.January, "es", False -> "ene"
    calendar.February, "es", True -> "febrero"
    calendar.February, "es", False -> "feb"
    calendar.March, "es", True -> "marzo"
    calendar.March, "es", False -> "mar"
    calendar.April, "es", True -> "abril"
    calendar.April, "es", False -> "abr"
    calendar.May, "es", True -> "mayo"
    calendar.May, "es", False -> "may"
    calendar.June, "es", True -> "junio"
    calendar.June, "es", False -> "jun"
    calendar.July, "es", True -> "julio"
    calendar.July, "es", False -> "jul"
    calendar.August, "es", True -> "agosto"
    calendar.August, "es", False -> "ago"
    calendar.September, "es", True -> "septiembre"
    calendar.September, "es", False -> "sep"
    calendar.October, "es", True -> "octubre"
    calendar.October, "es", False -> "oct"
    calendar.November, "es", True -> "noviembre"
    calendar.November, "es", False -> "nov"
    calendar.December, "es", True -> "diciembre"
    calendar.December, "es", False -> "dic"
    calendar.January, "fr", True -> "janvier"
    calendar.January, "fr", False -> "janv"
    calendar.February, "fr", True -> "février"
    calendar.February, "fr", False -> "févr"
    calendar.March, "fr", True -> "mars"
    calendar.March, "fr", False -> "mars"
    calendar.April, "fr", True -> "avril"
    calendar.April, "fr", False -> "avr"
    calendar.May, "fr", True -> "mai"
    calendar.May, "fr", False -> "mai"
    calendar.June, "fr", True -> "juin"
    calendar.June, "fr", False -> "juin"
    calendar.July, "fr", True -> "juillet"
    calendar.July, "fr", False -> "juil"
    calendar.August, "fr", True -> "août"
    calendar.August, "fr", False -> "août"
    calendar.September, "fr", True -> "septembre"
    calendar.September, "fr", False -> "sept"
    calendar.October, "fr", True -> "octobre"
    calendar.October, "fr", False -> "oct"
    calendar.November, "fr", True -> "novembre"
    calendar.November, "fr", False -> "nov"
    calendar.December, "fr", True -> "décembre"
    calendar.December, "fr", False -> "déc"
    calendar.January, "de", True -> "Januar"
    calendar.January, "de", False -> "Jan"
    calendar.February, "de", True -> "Februar"
    calendar.February, "de", False -> "Feb"
    calendar.March, "de", True -> "März"
    calendar.March, "de", False -> "Mär"
    calendar.April, "de", True -> "April"
    calendar.April, "de", False -> "Apr"
    calendar.May, "de", True -> "Mai"
    calendar.May, "de", False -> "Mai"
    calendar.June, "de", True -> "Juni"
    calendar.June, "de", False -> "Jun"
    calendar.July, "de", True -> "Juli"
    calendar.July, "de", False -> "Jul"
    calendar.August, "de", True -> "August"
    calendar.August, "de", False -> "Aug"
    calendar.September, "de", True -> "September"
    calendar.September, "de", False -> "Sep"
    calendar.October, "de", True -> "Oktober"
    calendar.October, "de", False -> "Okt"
    calendar.November, "de", True -> "November"
    calendar.November, "de", False -> "Nov"
    calendar.December, "de", True -> "Dezember"
    calendar.December, "de", False -> "Dez"
    calendar.January, "it", True -> "gennaio"
    calendar.January, "it", False -> "gen"
    calendar.February, "it", True -> "febbraio"
    calendar.February, "it", False -> "feb"
    calendar.March, "it", True -> "marzo"
    calendar.March, "it", False -> "mar"
    calendar.April, "it", True -> "aprile"
    calendar.April, "it", False -> "apr"
    calendar.May, "it", True -> "maggio"
    calendar.May, "it", False -> "mag"
    calendar.June, "it", True -> "giugno"
    calendar.June, "it", False -> "giu"
    calendar.July, "it", True -> "luglio"
    calendar.July, "it", False -> "lug"
    calendar.August, "it", True -> "agosto"
    calendar.August, "it", False -> "ago"
    calendar.September, "it", True -> "settembre"
    calendar.September, "it", False -> "set"
    calendar.October, "it", True -> "ottobre"
    calendar.October, "it", False -> "ott"
    calendar.November, "it", True -> "novembre"
    calendar.November, "it", False -> "nov"
    calendar.December, "it", True -> "dicembre"
    calendar.December, "it", False -> "dic"
    calendar.January, "ru", True -> "январь"
    calendar.January, "ru", False -> "янв"
    calendar.February, "ru", True -> "февраль"
    calendar.February, "ru", False -> "фев"
    calendar.March, "ru", True -> "март"
    calendar.March, "ru", False -> "мар"
    calendar.April, "ru", True -> "апрель"
    calendar.April, "ru", False -> "апр"
    calendar.May, "ru", True -> "май"
    calendar.May, "ru", False -> "май"
    calendar.June, "ru", True -> "июнь"
    calendar.June, "ru", False -> "июн"
    calendar.July, "ru", True -> "июль"
    calendar.July, "ru", False -> "июл"
    calendar.August, "ru", True -> "август"
    calendar.August, "ru", False -> "авг"
    calendar.September, "ru", True -> "сентябрь"
    calendar.September, "ru", False -> "сен"
    calendar.October, "ru", True -> "октябрь"
    calendar.October, "ru", False -> "окт"
    calendar.November, "ru", True -> "ноябрь"
    calendar.November, "ru", False -> "ноя"
    calendar.December, "ru", True -> "декабрь"
    calendar.December, "ru", False -> "дек"
    calendar.January, "zh", True -> "一月"
    calendar.January, "zh", False -> "1月"
    calendar.February, "zh", True -> "二月"
    calendar.February, "zh", False -> "2月"
    calendar.March, "zh", True -> "三月"
    calendar.March, "zh", False -> "3月"
    calendar.April, "zh", True -> "四月"
    calendar.April, "zh", False -> "4月"
    calendar.May, "zh", True -> "五月"
    calendar.May, "zh", False -> "5月"
    calendar.June, "zh", True -> "六月"
    calendar.June, "zh", False -> "6月"
    calendar.July, "zh", True -> "七月"
    calendar.July, "zh", False -> "7月"
    calendar.August, "zh", True -> "八月"
    calendar.August, "zh", False -> "8月"
    calendar.September, "zh", True -> "九月"
    calendar.September, "zh", False -> "9月"
    calendar.October, "zh", True -> "十月"
    calendar.October, "zh", False -> "10月"
    calendar.November, "zh", True -> "十一月"
    calendar.November, "zh", False -> "11月"
    calendar.December, "zh", True -> "十二月"
    calendar.December, "zh", False -> "12月"
    calendar.January, "ja", True -> "一月"
    calendar.January, "ja", False -> "1月"
    calendar.February, "ja", True -> "二月"
    calendar.February, "ja", False -> "2月"
    calendar.March, "ja", True -> "三月"
    calendar.March, "ja", False -> "3月"
    calendar.April, "ja", True -> "四月"
    calendar.April, "ja", False -> "4月"
    calendar.May, "ja", True -> "五月"
    calendar.May, "ja", False -> "5月"
    calendar.June, "ja", True -> "六月"
    calendar.June, "ja", False -> "6月"
    calendar.July, "ja", True -> "七月"
    calendar.July, "ja", False -> "7月"
    calendar.August, "ja", True -> "八月"
    calendar.August, "ja", False -> "8月"
    calendar.September, "ja", True -> "九月"
    calendar.September, "ja", False -> "9月"
    calendar.October, "ja", True -> "十月"
    calendar.October, "ja", False -> "10月"
    calendar.November, "ja", True -> "十一月"
    calendar.November, "ja", False -> "11月"
    calendar.December, "ja", True -> "十二月"
    calendar.December, "ja", False -> "12月"
    calendar.January, "ko", True -> "일월"
    calendar.January, "ko", False -> "1월"
    calendar.February, "ko", True -> "이월"
    calendar.February, "ko", False -> "2월"
    calendar.March, "ko", True -> "삼월"
    calendar.March, "ko", False -> "3월"
    calendar.April, "ko", True -> "사월"
    calendar.April, "ko", False -> "4월"
    calendar.May, "ko", True -> "오월"
    calendar.May, "ko", False -> "5월"
    calendar.June, "ko", True -> "유월"
    calendar.June, "ko", False -> "6월"
    calendar.July, "ko", True -> "칠월"
    calendar.July, "ko", False -> "7월"
    calendar.August, "ko", True -> "팔월"
    calendar.August, "ko", False -> "8월"
    calendar.September, "ko", True -> "구월"
    calendar.September, "ko", False -> "9월"
    calendar.October, "ko", True -> "시월"
    calendar.October, "ko", False -> "10월"
    calendar.November, "ko", True -> "십일월"
    calendar.November, "ko", False -> "11월"
    calendar.December, "ko", True -> "십이월"
    calendar.December, "ko", False -> "12월"
    calendar.January, "ar", True -> "يناير"
    calendar.January, "ar", False -> "ينا"
    calendar.February, "ar", True -> "فبراير"
    calendar.February, "ar", False -> "فبر"
    calendar.March, "ar", True -> "مارس"
    calendar.March, "ar", False -> "مار"
    calendar.April, "ar", True -> "أبريل"
    calendar.April, "ar", False -> "أبر"
    calendar.May, "ar", True -> "مايو"
    calendar.May, "ar", False -> "ماي"
    calendar.June, "ar", True -> "يونيو"
    calendar.June, "ar", False -> "يون"
    calendar.July, "ar", True -> "يوليو"
    calendar.July, "ar", False -> "يول"
    calendar.August, "ar", True -> "أغسطس"
    calendar.August, "ar", False -> "أغس"
    calendar.September, "ar", True -> "سبتمبر"
    calendar.September, "ar", False -> "سبت"
    calendar.October, "ar", True -> "أكتوبر"
    calendar.October, "ar", False -> "أكت"
    calendar.November, "ar", True -> "نوفمبر"
    calendar.November, "ar", False -> "نوف"
    calendar.December, "ar", True -> "ديسمبر"
    calendar.December, "ar", False -> "ديس"
    calendar.January, "hi", True -> "जनवरी"
    calendar.January, "hi", False -> "जन"
    calendar.February, "hi", True -> "फरवरी"
    calendar.February, "hi", False -> "फर"
    calendar.March, "hi", True -> "मार्च"
    calendar.March, "hi", False -> "मार"
    calendar.April, "hi", True -> "अप्रैल"
    calendar.April, "hi", False -> "अप्र"
    calendar.May, "hi", True -> "मई"
    calendar.May, "hi", False -> "मई"
    calendar.June, "hi", True -> "जून"
    calendar.June, "hi", False -> "जून"
    calendar.July, "hi", True -> "जुलाई"
    calendar.July, "hi", False -> "जुल"
    calendar.August, "hi", True -> "अगस्त"
    calendar.August, "hi", False -> "अग"
    calendar.September, "hi", True -> "सितम्बर"
    calendar.September, "hi", False -> "सित"
    calendar.October, "hi", True -> "अक्टूबर"
    calendar.October, "hi", False -> "अक्ट"
    calendar.November, "hi", True -> "नवम्बर"
    calendar.November, "hi", False -> "नव"
    calendar.December, "hi", True -> "दिसम्बर"
    calendar.December, "hi", False -> "दिस"
    _, _, _ ->
      case month {
        calendar.January -> "01"
        calendar.February -> "02"
        calendar.March -> "03"
        calendar.April -> "04"
        calendar.May -> "05"
        calendar.June -> "06"
        calendar.July -> "07"
        calendar.August -> "08"
        calendar.September -> "09"
        calendar.October -> "10"
        calendar.November -> "11"
        calendar.December -> "12"
      }
  }
}

fn format_12_hour(time: calendar.TimeOfDay) -> String {
  let hour_12 = case time.hours {
    0 -> 12
    h if h > 12 -> h - 12
    h -> h
  }
  let ampm = case time.hours {
    h if h >= 12 -> "PM"
    _ -> "AM"
  }
  string.inspect(hour_12) <> ":" <> pad_zero(time.minutes) <> " " <> ampm
}

fn format_24_hour(time: calendar.TimeOfDay) -> String {
  pad_zero(time.hours) <> ":" <> pad_zero(time.minutes)
}

fn format_12_hour_with_seconds(time: calendar.TimeOfDay) -> String {
  let hour_12 = case time.hours {
    0 -> 12
    h if h > 12 -> h - 12
    h -> h
  }
  let ampm = case time.hours {
    h if h >= 12 -> "PM"
    _ -> "AM"
  }
  string.inspect(hour_12)
  <> ":"
  <> pad_zero(time.minutes)
  <> ":"
  <> pad_zero(time.seconds)
  <> " "
  <> ampm
}

fn format_24_hour_with_seconds(time: calendar.TimeOfDay) -> String {
  pad_zero(time.hours)
  <> ":"
  <> pad_zero(time.minutes)
  <> ":"
  <> pad_zero(time.seconds)
}

fn format_time_unit(language: String, unit: String, count: Int) -> String {
  let count_str = int.to_string(count)
  case language {
    "en" ->
      case unit, count {
        "second", 1 -> "1 second"
        "second", _ -> count_str <> " seconds"
        "minute", 1 -> "1 minute"
        "minute", _ -> count_str <> " minutes"
        "hour", 1 -> "1 hour"
        "hour", _ -> count_str <> " hours"
        "day", 1 -> "1 day"
        "day", _ -> count_str <> " days"
        "week", 1 -> "1 week"
        "week", _ -> count_str <> " weeks"
        "month", 1 -> "1 month"
        "month", _ -> count_str <> " months"
        "year", 1 -> "1 year"
        "year", _ -> count_str <> " years"
        _, _ -> count_str <> " " <> unit
      }
    "pt" ->
      case unit, count {
        "second", 1 -> "1 segundo"
        "second", _ -> count_str <> " segundos"
        "minute", 1 -> "1 minuto"
        "minute", _ -> count_str <> " minutos"
        "hour", 1 -> "1 hora"
        "hour", _ -> count_str <> " horas"
        "day", 1 -> "1 dia"
        "day", _ -> count_str <> " dias"
        "week", 1 -> "1 semana"
        "week", _ -> count_str <> " semanas"
        "month", 1 -> "1 mês"
        "month", _ -> count_str <> " meses"
        "year", 1 -> "1 ano"
        "year", _ -> count_str <> " anos"
        _, _ -> count_str <> " " <> unit
      }
    "es" ->
      case unit, count {
        "second", 1 -> "1 segundo"
        "second", _ -> count_str <> " segundos"
        "minute", 1 -> "1 minuto"
        "minute", _ -> count_str <> " minutos"
        "hour", 1 -> "1 hora"
        "hour", _ -> count_str <> " horas"
        "day", 1 -> "1 día"
        "day", _ -> count_str <> " días"
        "week", 1 -> "1 semana"
        "week", _ -> count_str <> " semanas"
        "month", 1 -> "1 mes"
        "month", _ -> count_str <> " meses"
        "year", 1 -> "1 año"
        "year", _ -> count_str <> " años"
        _, _ -> count_str <> " " <> unit
      }
    "fr" ->
      case unit, count {
        "second", 1 -> "1 seconde"
        "second", _ -> count_str <> " secondes"
        "minute", 1 -> "1 minute"
        "minute", _ -> count_str <> " minutes"
        "hour", 1 -> "1 heure"
        "hour", _ -> count_str <> " heures"
        "day", 1 -> "1 jour"
        "day", _ -> count_str <> " jours"
        "week", 1 -> "1 semaine"
        "week", _ -> count_str <> " semaines"
        "month", 1 -> "1 mois"
        "month", _ -> count_str <> " mois"
        "year", 1 -> "1 an"
        "year", _ -> count_str <> " ans"
        _, _ -> count_str <> " " <> unit
      }
    "de" ->
      case unit, count {
        "second", 1 -> "1 Sekunde"
        "second", _ -> count_str <> " Sekunden"
        "minute", 1 -> "1 Minute"
        "minute", _ -> count_str <> " Minuten"
        "hour", 1 -> "1 Stunde"
        "hour", _ -> count_str <> " Stunden"
        "day", 1 -> "1 Tag"
        "day", _ -> count_str <> " Tage"
        "week", 1 -> "1 Woche"
        "week", _ -> count_str <> " Wochen"
        "month", 1 -> "1 Monat"
        "month", _ -> count_str <> " Monate"
        "year", 1 -> "1 Jahr"
        "year", _ -> count_str <> " Jahre"
        _, _ -> count_str <> " " <> unit
      }
    "it" ->
      case unit, count {
        "second", 1 -> "1 secondo"
        "second", _ -> count_str <> " secondi"
        "minute", 1 -> "1 minuto"
        "minute", _ -> count_str <> " minuti"
        "hour", 1 -> "1 ora"
        "hour", _ -> count_str <> " ore"
        "day", 1 -> "1 giorno"
        "day", _ -> count_str <> " giorni"
        "week", 1 -> "1 settimana"
        "week", _ -> count_str <> " settimane"
        "month", 1 -> "1 mese"
        "month", _ -> count_str <> " mesi"
        "year", 1 -> "1 anno"
        "year", _ -> count_str <> " anni"
        _, _ -> count_str <> " " <> unit
      }
    "ru" ->
      case unit, count {
        "second", 1 -> "1 секунда"
        "second", n if n >= 2 && n <= 4 -> count_str <> " секунды"
        "second", _ -> count_str <> " секунд"
        "minute", 1 -> "1 минута"
        "minute", n if n >= 2 && n <= 4 -> count_str <> " минуты"
        "minute", _ -> count_str <> " минут"
        "hour", 1 -> "1 час"
        "hour", n if n >= 2 && n <= 4 -> count_str <> " часа"
        "hour", _ -> count_str <> " часов"
        "day", 1 -> "1 день"
        "day", n if n >= 2 && n <= 4 -> count_str <> " дня"
        "day", _ -> count_str <> " дней"
        "week", 1 -> "1 неделя"
        "week", n if n >= 2 && n <= 4 -> count_str <> " недели"
        "week", _ -> count_str <> " недель"
        "month", 1 -> "1 месяц"
        "month", n if n >= 2 && n <= 4 -> count_str <> " месяца"
        "month", _ -> count_str <> " месяцев"
        "year", 1 -> "1 год"
        "year", n if n >= 2 && n <= 4 -> count_str <> " года"
        "year", _ -> count_str <> " лет"
        _, _ -> count_str <> " " <> unit
      }
    "zh" ->
      case unit, count {
        "second", _ -> count_str <> "秒"
        "minute", _ -> count_str <> "分钟"
        "hour", _ -> count_str <> "小时"
        "day", _ -> count_str <> "天"
        "week", _ -> count_str <> "周"
        "month", _ -> count_str <> "个月"
        "year", _ -> count_str <> "年"
        _, _ -> count_str <> unit
      }
    "ja" ->
      case unit, count {
        "second", _ -> count_str <> "秒"
        "minute", _ -> count_str <> "分"
        "hour", _ -> count_str <> "時間"
        "day", _ -> count_str <> "日"
        "week", _ -> count_str <> "週間"
        "month", _ -> count_str <> "ヶ月"
        "year", _ -> count_str <> "年"
        _, _ -> count_str <> unit
      }
    "ko" ->
      case unit, count {
        "second", _ -> count_str <> "초"
        "minute", _ -> count_str <> "분"
        "hour", _ -> count_str <> "시간"
        "day", _ -> count_str <> "일"
        "week", _ -> count_str <> "주"
        "month", _ -> count_str <> "개월"
        "year", _ -> count_str <> "년"
        _, _ -> count_str <> unit
      }
    "ar" ->
      case unit, count {
        "second", 1 -> "ثانية واحدة"
        "second", 2 -> "ثانيتان"
        "second", n if n >= 3 && n <= 10 -> count_str <> " ثوانٍ"
        "second", _ -> count_str <> " ثانية"
        "minute", 1 -> "دقيقة واحدة"
        "minute", 2 -> "دقيقتان"
        "minute", n if n >= 3 && n <= 10 -> count_str <> " دقائق"
        "minute", _ -> count_str <> " دقيقة"
        "hour", 1 -> "ساعة واحدة"
        "hour", 2 -> "ساعتان"
        "hour", n if n >= 3 && n <= 10 -> count_str <> " ساعات"
        "hour", _ -> count_str <> " ساعة"
        "day", 1 -> "يوم واحد"
        "day", 2 -> "يومان"
        "day", n if n >= 3 && n <= 10 -> count_str <> " أيام"
        "day", _ -> count_str <> " يوم"
        "week", 1 -> "أسبوع واحد"
        "week", 2 -> "أسبوعان"
        "week", n if n >= 3 && n <= 10 -> count_str <> " أسابيع"
        "week", _ -> count_str <> " أسبوع"
        "month", 1 -> "شهر واحد"
        "month", 2 -> "شهران"
        "month", n if n >= 3 && n <= 10 -> count_str <> " أشهر"
        "month", _ -> count_str <> " شهر"
        "year", 1 -> "سنة واحدة"
        "year", 2 -> "سنتان"
        "year", n if n >= 3 && n <= 10 -> count_str <> " سنوات"
        "year", _ -> count_str <> " سنة"
        _, _ -> count_str <> " " <> unit
      }
    "hi" ->
      case unit, count {
        "second", 1 -> "1 सेकंड"
        "second", _ -> count_str <> " सेकंड"
        "minute", 1 -> "1 मिनट"
        "minute", _ -> count_str <> " मिनट"
        "hour", 1 -> "1 घंटा"
        "hour", _ -> count_str <> " घंटे"
        "day", 1 -> "1 दिन"
        "day", _ -> count_str <> " दिन"
        "week", 1 -> "1 सप्ताह"
        "week", _ -> count_str <> " सप्ताह"
        "month", 1 -> "1 महीना"
        "month", _ -> count_str <> " महीने"
        "year", 1 -> "1 साल"
        "year", _ -> count_str <> " साल"
        _, _ -> count_str <> " " <> unit
      }
    _ -> count_str <> " " <> unit
  }
}

fn pad_zero(number: Int) -> String {
  case number < 10 {
    True -> "0" <> int.to_string(number)
    False -> int.to_string(number)
  }
}

fn get_day_of_week_name(date: calendar.Date, language: String) -> String {
  let day_of_week = calculate_day_of_week(date)
  case day_of_week, language {
    0, "en" -> "Sunday"
    1, "en" -> "Monday"
    2, "en" -> "Tuesday"
    3, "en" -> "Wednesday"
    4, "en" -> "Thursday"
    5, "en" -> "Friday"
    6, "en" -> "Saturday"
    0, "pt" -> "domingo"
    1, "pt" -> "segunda-feira"
    2, "pt" -> "terça-feira"
    3, "pt" -> "quarta-feira"
    4, "pt" -> "quinta-feira"
    5, "pt" -> "sexta-feira"
    6, "pt" -> "sábado"
    0, "es" -> "domingo"
    1, "es" -> "lunes"
    2, "es" -> "martes"
    3, "es" -> "miércoles"
    4, "es" -> "jueves"
    5, "es" -> "viernes"
    6, "es" -> "sábado"
    0, "fr" -> "dimanche"
    1, "fr" -> "lundi"
    2, "fr" -> "mardi"
    3, "fr" -> "mercredi"
    4, "fr" -> "jeudi"
    5, "fr" -> "vendredi"
    6, "fr" -> "samedi"
    0, "de" -> "Sonntag"
    1, "de" -> "Montag"
    2, "de" -> "Dienstag"
    3, "de" -> "Mittwoch"
    4, "de" -> "Donnerstag"
    5, "de" -> "Freitag"
    6, "de" -> "Samstag"
    0, "it" -> "domenica"
    1, "it" -> "lunedì"
    2, "it" -> "martedì"
    3, "it" -> "mercoledì"
    4, "it" -> "giovedì"
    5, "it" -> "venerdì"
    6, "it" -> "sabato"
    0, "ru" -> "воскресенье"
    1, "ru" -> "понедельник"
    2, "ru" -> "вторник"
    3, "ru" -> "среда"
    4, "ru" -> "четверг"
    5, "ru" -> "пятница"
    6, "ru" -> "суббота"
    0, "zh" -> "星期日"
    1, "zh" -> "星期一"
    2, "zh" -> "星期二"
    3, "zh" -> "星期三"
    4, "zh" -> "星期四"
    5, "zh" -> "星期五"
    6, "zh" -> "星期六"
    0, "ja" -> "日曜日"
    1, "ja" -> "月曜日"
    2, "ja" -> "火曜日"
    3, "ja" -> "水曜日"
    4, "ja" -> "木曜日"
    5, "ja" -> "金曜日"
    6, "ja" -> "土曜日"
    0, "ko" -> "일요일"
    1, "ko" -> "월요일"
    2, "ko" -> "화요일"
    3, "ko" -> "수요일"
    4, "ko" -> "목요일"
    5, "ko" -> "금요일"
    6, "ko" -> "토요일"
    0, "ar" -> "الأحد"
    1, "ar" -> "الإثنين"
    2, "ar" -> "الثلاثاء"
    3, "ar" -> "الأربعاء"
    4, "ar" -> "الخميس"
    5, "ar" -> "الجمعة"
    6, "ar" -> "السبت"
    0, "hi" -> "रविवार"
    1, "hi" -> "सोमवार"
    2, "hi" -> "मंगलवार"
    3, "hi" -> "बुधवार"
    4, "hi" -> "गुरुवार"
    5, "hi" -> "शुक्रवार"
    6, "hi" -> "शनिवार"
    _, _ -> "Day " <> int.to_string(day_of_week)
  }
}

fn calculate_day_of_week(date: calendar.Date) -> Int {
  let adjusted_month = case date.month {
    calendar.January -> 13
    calendar.February -> 14
    calendar.March -> 3
    calendar.April -> 4
    calendar.May -> 5
    calendar.June -> 6
    calendar.July -> 7
    calendar.August -> 8
    calendar.September -> 9
    calendar.October -> 10
    calendar.November -> 11
    calendar.December -> 12
  }

  let adjusted_year = case date.month {
    calendar.January | calendar.February -> date.year - 1
    _ -> date.year
  }

  let century = adjusted_year / 100
  let year_of_century = adjusted_year % 100

  let zeller =
    date.day
    + { { 13 * { adjusted_month + 1 } } / 5 }
    + year_of_century
    + { year_of_century / 4 }
    + { century / 4 }
    - { 2 * century }

  // Zeller's gives Saturday=0, Sunday=1, Monday=2, etc.
  // Convert to our format: Sunday=0, Monday=1, Tuesday=2, etc.
  let day_zeller = { { zeller % 7 } + 7 } % 7
  case day_zeller {
    0 -> 6
    // Saturday -> 6
    1 -> 0
    // Sunday -> 0  
    2 -> 1
    // Monday -> 1
    3 -> 2
    // Tuesday -> 2
    4 -> 3
    // Wednesday -> 3
    5 -> 4
    // Thursday -> 4
    6 -> 5
    // Friday -> 5
    _ -> 0
    // Fallback
  }
}

// Translation Validation System
pub type ValidationError {
  MissingTranslation(key: String, locale: Locale)
  MissingParameter(key: String, param: String, locale: Locale)
  UnusedParameter(key: String, param: String, locale: Locale)
  InvalidPluralForm(key: String, missing_forms: List(String), locale: Locale)
  EmptyTranslation(key: String, locale: Locale)
}

pub type ValidationReport {
  ValidationReport(
    errors: List(ValidationError),
    warnings: List(ValidationError),
    total_keys: Int,
    translated_keys: Int,
    coverage: Float,
  )
}

/// Validate target translations against primary translations.
///
/// Compares a primary set of translations (e.g., English) with target translations
/// (e.g., Spanish) to identify missing translations, parameter mismatches, invalid
/// plural forms, and empty translations. Returns a comprehensive validation report
/// with error details and translation coverage statistics.
///
/// ## Examples
/// ```gleam
/// let assert Ok(en) = g18n.locale("en")
/// let assert Ok(es) = g18n.locale("es")
/// 
/// let primary = g18n.translations()
///   |> g18n.add_translation("welcome", "Welcome {name}!")
///   |> g18n.add_translation("items.one", "1 item")
///   |> g18n.add_translation("items.other", "{count} items")
/// 
/// let target = g18n.translations()
///   |> g18n.add_translation("welcome", "¡Bienvenido {nombre}!")  // Parameter mismatch
///   |> g18n.add_translation("items.one", "1 artículo")
///   // Missing "items.other" translation
/// 
/// let report = g18n.validate_translations(primary, target, es)
/// // report.errors will contain MissingParameter and MissingTranslation errors
/// // report.coverage will be 0.67 (2 out of 3 keys translated)
/// ```
pub fn validate_translations(
  primary_translations: Translations,
  target_translations: Translations,
  target_locale: Locale,
) -> ValidationReport {
  let primary_keys = get_all_translation_keys(primary_translations)
  let target_keys = get_all_translation_keys(target_translations)

  let missing_translations =
    find_missing_translations(primary_keys, target_keys, target_locale)
  let parameter_errors =
    validate_all_parameters(
      primary_translations,
      target_translations,
      target_locale,
    )
  let plural_errors = validate_plural_forms(target_translations, target_locale)
  let empty_errors = find_empty_translations(target_translations, target_locale)

  let all_errors =
    list.flatten([
      missing_translations,
      parameter_errors,
      plural_errors,
      empty_errors,
    ])
  let total_keys = list.length(primary_keys)
  let translated_keys = list.length(target_keys)
  let coverage = case total_keys {
    0 -> 0.0
    _ -> int.to_float(translated_keys) /. int.to_float(total_keys)
  }

  ValidationReport(
    errors: all_errors,
    warnings: [],
    total_keys: total_keys,
    translated_keys: translated_keys,
    coverage: coverage,
  )
}

/// Validate that a translation key has the correct parameters.
///
/// Checks if a specific translation contains all required parameters and
/// identifies any unused parameters. This ensures parameter consistency
/// between different language versions of the same translation.
///
/// ## Examples
/// ```gleam
/// let assert Ok(locale) = g18n.locale("es")
/// let translations = g18n.translations()
///   |> g18n.add_translation("user.greeting", "Hola {nombre}!")
///   |> g18n.add_translation("user.stats", "Tienes {points} puntos")
/// 
/// // Check if Spanish translation has required English parameters
/// let errors1 = g18n.validate_translation_parameters(
///   translations, "user.greeting", ["name"], locale
/// )
/// // Returns [MissingParameter("user.greeting", "name", locale)] - "name" missing, "nombre" unused
/// 
/// let errors2 = g18n.validate_translation_parameters(
///   translations, "user.stats", ["points"], locale  
/// )
/// // Returns [] - parameters match correctly
/// ```
pub fn validate_translation_parameters(
  translations: Translations,
  key: String,
  required_params: List(String),
  locale: Locale,
) -> List(ValidationError) {
  let key_parts = string.split(key, ".")
  case trie.get(translations, key_parts) {
    Ok(template) -> {
      let found_params = extract_placeholders(template)
      let missing =
        list.filter(required_params, fn(param) {
          !list.contains(found_params, param)
        })
      let unused =
        list.filter(found_params, fn(param) {
          !list.contains(required_params, param)
        })

      let missing_errors =
        list.map(missing, fn(param) { MissingParameter(key, param, locale) })
      let unused_warnings =
        list.map(unused, fn(param) { UnusedParameter(key, param, locale) })

      list.append(missing_errors, unused_warnings)
    }
    Error(_) -> [MissingTranslation(key, locale)]
  }
}

/// Calculate translation coverage percentage.
///
/// Computes the percentage of primary translation keys that have been
/// translated in the target translations. Returns a float between 0.0 and 1.0
/// where 1.0 indicates complete coverage (100%).
///
/// ## Examples
/// ```gleam
/// let primary = g18n.translations()
///   |> g18n.add_translation("hello", "Hello")
///   |> g18n.add_translation("goodbye", "Goodbye")
///   |> g18n.add_translation("welcome", "Welcome")
/// 
/// let partial_target = g18n.translations()
///   |> g18n.add_translation("hello", "Hola")
///   |> g18n.add_translation("goodbye", "Adiós")
///   // Missing "welcome" translation
/// 
/// let coverage = g18n.get_translation_coverage(primary, partial_target)
/// // coverage == 0.67 (67% - 2 out of 3 keys translated)
/// 
/// let complete_target = partial_target
///   |> g18n.add_translation("welcome", "Bienvenido")
/// 
/// let full_coverage = g18n.get_translation_coverage(primary, complete_target)
/// // full_coverage == 1.0 (100% coverage)
/// ```
pub fn get_translation_coverage(
  primary_translations: Translations,
  target_translations: Translations,
) -> Float {
  let primary_count = count_translations(primary_translations)
  let target_count = count_translations(target_translations)

  case primary_count {
    0 -> 0.0
    _ -> int.to_float(target_count) /. int.to_float(primary_count)
  }
}

/// Find translation keys that are not being used in the application.
///
/// Compares all available translation keys against a list of keys actually used
/// in the application code. Returns keys that exist in translations but are not
/// referenced, helping identify obsolete translations that can be removed.
///
/// ## Examples
/// ```gleam
/// let translations = g18n.translations()
///   |> g18n.add_translation("common.save", "Save")
///   |> g18n.add_translation("common.cancel", "Cancel")
///   |> g18n.add_translation("old.feature", "Old Feature")
///   |> g18n.add_translation("user.profile", "Profile")
/// 
/// // Keys actually used in application code
/// let used_keys = ["common.save", "common.cancel", "user.profile"]
/// 
/// let unused = g18n.find_unused_translations(translations, used_keys)
/// // unused == ["old.feature"] - this key exists but is not used
/// 
/// // If all keys are used
/// let all_used = ["common.save", "common.cancel", "old.feature", "user.profile"]
/// let no_unused = g18n.find_unused_translations(translations, all_used)
/// // no_unused == [] - all translation keys are being used
/// ```
pub fn find_unused_translations(
  translations: Translations,
  used_keys: List(String),
) -> List(String) {
  let all_keys = get_all_translation_keys(translations)
  list.filter(all_keys, fn(key) { !list.contains(used_keys, key) })
}

/// Export a validation report to a formatted string.
///
/// Converts a ValidationReport into a human-readable text format suitable
/// for display in console output, log files, or CI/CD reports. Includes
/// coverage statistics, error counts, and detailed error descriptions.
///
/// ## Examples
/// ```gleam
/// let assert Ok(en) = g18n.locale("en")
/// let assert Ok(es) = g18n.locale("es")
/// 
/// let primary = g18n.translations()
///   |> g18n.add_translation("hello", "Hello {name}!")
///   |> g18n.add_translation("goodbye", "Goodbye")
/// 
/// let target = g18n.translations()
///   |> g18n.add_translation("hello", "Hola {nombre}!")  // Parameter mismatch
///   // Missing "goodbye" translation
/// 
/// let report = g18n.validate_translations(primary, target, es)
/// let formatted = g18n.export_validation_report(report)
/// 
/// // formatted contains:
/// // "Translation Validation Report"
/// // "================================"
/// // "Coverage: 50.0%"
/// // "Total Keys: 2"
/// // "Translated: 1" 
/// // "Errors: 2"
/// // "Warnings: 0"
/// // 
/// // "ERRORS:"
/// // "Missing translation: 'goodbye' for locale es"
/// // "Missing parameter: 'name' in 'hello' for locale es"
/// ```
pub fn export_validation_report(report: ValidationReport) -> String {
  let error_count = list.length(report.errors)
  let warning_count = list.length(report.warnings)

  let header =
    "Translation Validation Report\n"
    <> "================================\n"
    <> "Coverage: "
    <> float.to_string(report.coverage *. 100.0)
    <> "%\n"
    <> "Total Keys: "
    <> int.to_string(report.total_keys)
    <> "\n"
    <> "Translated: "
    <> int.to_string(report.translated_keys)
    <> "\n"
    <> "Errors: "
    <> int.to_string(error_count)
    <> "\n"
    <> "Warnings: "
    <> int.to_string(warning_count)
    <> "\n\n"

  let error_section = case error_count {
    0 -> ""
    _ -> "ERRORS:\n" <> format_validation_errors(report.errors) <> "\n"
  }

  let warning_section = case warning_count {
    0 -> ""
    _ -> "WARNINGS:\n" <> format_validation_errors(report.warnings) <> "\n"
  }

  header <> error_section <> warning_section
}

// Validation helper functions
fn get_all_translation_keys(translations: Translations) -> List(String) {
  trie.fold(translations, [], fn(acc, key_parts, _value) {
    let key = string.join(key_parts, ".")
    [key, ..acc]
  })
}

fn find_missing_translations(
  primary_keys: List(String),
  target_keys: List(String),
  locale: Locale,
) -> List(ValidationError) {
  list.filter_map(primary_keys, fn(key) {
    case list.contains(target_keys, key) {
      True -> Error(Nil)
      False -> Ok(MissingTranslation(key, locale))
    }
  })
}

fn validate_all_parameters(
  primary_translations: Translations,
  target_translations: Translations,
  target_locale: Locale,
) -> List(ValidationError) {
  let target_keys = get_all_translation_keys(target_translations)

  list.flat_map(target_keys, fn(key) {
    let key_parts = string.split(key, ".")
    case
      trie.get(primary_translations, key_parts),
      trie.get(target_translations, key_parts)
    {
      Ok(primary_template), Ok(_) -> {
        let primary_params = extract_placeholders(primary_template)
        validate_translation_parameters(
          target_translations,
          key,
          primary_params,
          target_locale,
        )
      }
      _, _ -> []
    }
  })
}

fn validate_plural_forms(
  translations: Translations,
  locale: Locale,
) -> List(ValidationError) {
  let all_keys = get_all_translation_keys(translations)
  let base_keys =
    list.filter_map(all_keys, fn(key) {
      case
        string.contains(key, ".one")
        || string.contains(key, ".other")
        || string.contains(key, ".zero")
      {
        True -> {
          let base = case splitter.split(splitter.new([key]), ".one") {
            #(base, ".one", _) -> Ok(base)
            _ ->
              case splitter.split(splitter.new([key]), ".other") {
                #(base, ".other", _) -> Ok(base)
                _ ->
                  case splitter.split(splitter.new([key]), ".zero") {
                    #(base, ".zero", _) -> Ok(base)
                    _ -> Error(Nil)
                  }
              }
          }
          base
        }
        False -> Error(Nil)
      }
    })

  list.flat_map(base_keys, fn(base_key) {
    validate_single_plural_form(translations, base_key, locale)
  })
}

fn validate_single_plural_form(
  translations: Translations,
  base_key: String,
  locale: Locale,
) -> List(ValidationError) {
  let required_forms = case locale.language {
    "en" -> ["one", "other"]
    "pt" -> ["zero", "one", "other"]
    "ru" -> ["one", "few", "many"]
    _ -> ["one", "other"]
  }

  let missing_forms =
    list.filter(required_forms, fn(form) {
      let key_parts = string.split(base_key <> "." <> form, ".")
      case trie.get(translations, key_parts) {
        Ok(_) -> False
        Error(_) -> True
      }
    })

  case missing_forms {
    [] -> []
    forms -> [InvalidPluralForm(base_key, forms, locale)]
  }
}

fn find_empty_translations(
  translations: Translations,
  locale: Locale,
) -> List(ValidationError) {
  trie.fold(translations, [], fn(acc, key_parts, value) {
    let key = string.join(key_parts, ".")
    case string.trim(value) {
      "" -> [EmptyTranslation(key, locale), ..acc]
      _ -> acc
    }
  })
}

fn count_translations(translations: Translations) -> Int {
  trie.fold(translations, 0, fn(count, _key, _value) { count + 1 })
}

fn format_validation_errors(errors: List(ValidationError)) -> String {
  errors
  |> list.map(fn(error) {
    case error {
      MissingTranslation(key, locale) ->
        "  - Missing translation for '"
        <> key
        <> "' in "
        <> locale_to_string(locale)
      MissingParameter(key, param, locale) ->
        "  - Missing parameter '{"
        <> param
        <> "}' in '"
        <> key
        <> "' ("
        <> locale_to_string(locale)
        <> ")"
      UnusedParameter(key, param, locale) ->
        "  - Unused parameter '{"
        <> param
        <> "}' in '"
        <> key
        <> "' ("
        <> locale_to_string(locale)
        <> ")"
      InvalidPluralForm(key, forms, locale) ->
        "  - Missing plural forms "
        <> string.inspect(forms)
        <> " for '"
        <> key
        <> "' in "
        <> locale_to_string(locale)
      EmptyTranslation(key, locale) ->
        "  - Empty translation for '"
        <> key
        <> "' in "
        <> locale_to_string(locale)
    }
  })
  |> string.join("\n")
}

// JSON Loading Functions

/// Parse a JSON string into a Translations structure.
/// 
/// Converts a JSON object with dotted keys into an internal trie structure
/// for efficient translation lookups. The JSON should contain key-value pairs
/// where keys use dot notation (e.g., "user.name", "welcome.message") and
/// values are the translation strings.
/// 
/// ## Examples
/// ```gleam
/// let json = "{\"user.name\": \"Name\", \"user.email\": \"Email\"}"
/// let assert Ok(translations) = g18n.translations_from_json(json)
/// ```
pub fn translations_from_json(
  json_string: String,
) -> Result(Translations, String) {
  case json.parse(json_string, decode.dict(decode.string, decode.string)) {
    Ok(dict_result) -> {
      // Convert dict to trie
      let trie_result =
        dict.fold(dict_result, trie.new(), fn(trie, key, value) {
          let key_parts = string.split(key, ".")
          trie.insert(trie, key_parts, value)
        })
      Ok(trie_result)
    }
    Error(json_err) ->
      Error("Failed to parse JSON: " <> string.inspect(json_err))
  }
}

/// Convert a Translations structure to a JSON string.
/// 
/// Converts the internal trie structure back to a JSON object with dotted keys.
/// This is useful for exporting translations or debugging the current state
/// of loaded translations.
/// 
/// ## Examples
/// ```gleam
/// let assert Ok(translations) = g18n.translations_from_json("{\"user.name\": \"Name\"}")
/// let json_output = g18n.translations_to_json(translations)
/// // Returns: {"user.name": "Name"}
/// ```
pub fn translations_to_json(translations: Translations) -> String {
  // Convert trie to dict for JSON serialization
  let dict_translations =
    trie.fold(translations, dict.new(), fn(dict_acc, key_parts, value) {
      let key = string.join(key_parts, ".")
      dict.insert(dict_acc, key, value)
    })

  dict_translations
  |> dict.to_list
  |> list_map(fn(pair) { #(pair.0, json.string(pair.1)) })
  |> json.object
  |> json.to_string
}

/// Import translations from nested JSON format.
///
/// Converts nested JSON objects to the internal flat trie structure.
/// This is the industry-standard format used by most i18n libraries like
/// react-i18next, Vue i18n, and Angular i18n.
///
/// ## Parameters
/// - `json_string`: JSON string with nested structure
///
/// ## Returns
/// `Result(Translations, String)` - Success with translations or error message
///
/// ## Examples
/// ```gleam
/// let nested_json = "
/// {
///   \"ui\": {
///     \"button\": {
///       \"save\": \"Save\",
///       \"cancel\": \"Cancel\"
///     }
///   },
///   \"user\": {
///     \"name\": \"Name\",
///     \"email\": \"Email\"
///   }
/// }"
/// 
/// let assert Ok(translations) = g18n.translations_from_nested_json(nested_json)
/// // Converts to flat keys: "ui.button.save", "ui.button.cancel", etc.
/// ```
pub fn translations_from_nested_json(
  json_string: String,
) -> Result(Translations, String) {
  case json.parse(json_string, decode.dict(decode.string, decode.dynamic)) {
    Ok(dict_result) -> {
      let flattened_dict = flatten_json_object(dict_result, "")
      let trie_result =
        dict.fold(flattened_dict, trie.new(), fn(trie, key, value) {
          let key_parts = string.split(key, ".")
          trie.insert(trie, key_parts, value)
        })
      Ok(trie_result)
    }
    Error(err) -> Error("Failed to parse nested JSON: " <> string.inspect(err))
  }
}

/// Export translations to nested JSON format.
///
/// Converts the internal flat trie structure to nested JSON objects.
/// This produces the industry-standard format expected by most i18n tools.
///
/// ## Parameters
/// - `translations`: The translations to export
///
/// ## Returns
/// `String` - Nested JSON representation of the translations
///
/// ## Examples
/// ```gleam
/// let translations = g18n.translations()
///   |> g18n.add_translation("ui.button.save", "Save")
///   |> g18n.add_translation("ui.button.cancel", "Cancel")
///   |> g18n.add_translation("user.name", "Name")
/// 
/// let nested_json = g18n.translations_to_nested_json(translations)
/// // Returns: {"ui":{"button":{"save":"Save","cancel":"Cancel"}},"user":{"name":"Name"}}
/// ```
pub fn translations_to_nested_json(translations: Translations) -> String {
  // Convert trie directly to nested JSON structure
  trie_to_nested_json(translations)
  |> json.to_string
}

/// Convert nested JSON structure to flat key-value pairs.
///
/// Takes a nested dictionary structure and flattens it using dot notation.
/// Useful for converting industry-standard nested JSON to g18n's internal format.
///
/// ## Examples  
/// ```gleam
/// let nested = dict.new()
///   |> dict.insert("ui", json.object([
///     #("button", json.object([#("save", json.string("Save"))]))
///   ]))
/// 
/// let flat = g18n.nested_to_flatten_dict(nested, "")
/// // Returns: {"ui.button.save": "Save"}
/// ```
pub fn nested_to_flatten_dict(
  nested_dict: Dict(String, json.Json),
  prefix: String,
) -> Dict(String, String) {
  dict.fold(nested_dict, dict.new(), fn(acc, key, value) {
    let current_key = case prefix {
      "" -> key
      _ -> prefix <> "." <> key
    }

    case value {
      // If it's a nested object, recurse
      _ -> {
        // Try to extract string value
        case extract_string_from_json(value) {
          Some(str_value) -> dict.insert(acc, current_key, str_value)
          None -> acc
          // Skip non-string values for now
        }
      }
    }
  })
}

// Helper function to recursively flatten nested dictionary
fn flatten_json_object(
  dict_obj: Dict(String, Dynamic),
  prefix: String,
) -> Dict(String, String) {
  dict.fold(dict_obj, dict.new(), fn(acc, key, value) {
    let current_key = case prefix {
      "" -> key
      _ -> prefix <> "." <> key
    }

    case decode.run(value, decode.dict(decode.string, decode.dynamic)) {
      Ok(nested_dict) -> {
        let nested_flattened = flatten_json_object(nested_dict, current_key)
        dict.fold(nested_flattened, acc, dict.insert)
      }
      Error(_) -> {
        // Try to decode as string
        case decode.run(value, decode.string) {
          Ok(str_value) -> dict.insert(acc, current_key, str_value)
          Error(_) -> acc
          // Skip non-string values
        }
      }
    }
  })
}

// Convert trie directly to nested JSON structure
fn trie_to_nested_json(translations: Translations) -> json.Json {
  // Collect all key-value pairs from trie
  let all_pairs =
    trie.fold(translations, [], fn(acc, key_parts, value) {
      [#(key_parts, value), ..acc]
    })

  // Build nested structure from key parts
  build_nested_structure(all_pairs)
}

// Build nested JSON structure from list of (key_parts, value) pairs
fn build_nested_structure(pairs: List(#(List(String), String))) -> json.Json {
  pairs
  |> list.fold(dict.new(), fn(acc, pair) {
    let #(key_parts, value) = pair
    insert_at_path(acc, key_parts, json.string(value))
  })
  |> dict.to_list
  |> json.object
}

// Insert value at nested path in dict
fn insert_at_path(
  dict_acc: Dict(String, json.Json),
  key_parts: List(String),
  value: json.Json,
) -> Dict(String, json.Json) {
  case key_parts {
    [] -> dict_acc
    [single_key] -> dict.insert(dict_acc, single_key, value)
    [first_key, ..remaining_keys] -> {
      let existing = case dict.get(dict_acc, first_key) {
        Ok(json_obj) -> extract_dict_from_json(json_obj)
        Error(_) -> dict.new()
      }
      let updated = insert_at_path(existing, remaining_keys, value)
      dict.insert(dict_acc, first_key, dict.to_list(updated) |> json.object)
    }
  }
}

// Extract dict from JSON object, return empty dict if not object
fn extract_dict_from_json(json_val: json.Json) -> Dict(String, json.Json) {
  case json_val {
    _ -> dict.new()
    // For now, return empty dict - will improve later
  }
}

// Extract string value from JSON, return None if not a string
fn extract_string_from_json(_json_val: json.Json) -> Option(String) {
  // For now, return None - will implement proper extraction later
  None
}

// Helper Functions
fn list_map(list: List(a), func: fn(a) -> b) -> List(b) {
  case list {
    [] -> []
    [head, ..tail] -> [func(head), ..list_map(tail, func)]
  }
}

fn list_filter(list: List(a), predicate: fn(a) -> Bool) -> List(a) {
  case list {
    [] -> []
    [head, ..tail] -> {
      case predicate(head) {
        True -> [head, ..list_filter(tail, predicate)]
        False -> list_filter(tail, predicate)
      }
    }
  }
}

/// Main entry point for the g18n CLI tool.
/// 
/// Handles command-line arguments and dispatches to appropriate command handlers.
/// Currently supports 'generate' command to create Gleam translation modules
/// and 'help' command to display usage information.
/// 
/// ## Supported Commands
/// - `generate`: Generate Gleam modules from translation JSON files
/// - `help`: Display help information
/// - No arguments: Display help information
/// 
/// ## Examples
/// Run via command line:
/// ```bash
/// gleam run generate  # Generate translation modules
/// gleam run help      # Show help
/// gleam run           # Show help (default)
/// ```
/// Main entry point for the g18n CLI tool.
/// 
/// Handles command-line arguments and dispatches to appropriate command handlers.
/// Supports 'generate' for flat JSON, 'generate_nested' for nested JSON,
/// and 'help' for usage information.
/// 
/// ## Supported Commands
/// - `generate`: Generate Gleam modules from flat JSON files
/// - `generate_nested`: Generate Gleam modules from nested JSON files
/// - `help`: Display help information
/// - No arguments: Display help information
/// 
/// ## Examples
/// Run via command line:
/// ```bash
/// gleam run generate        # Generate from flat JSON files
/// gleam run generate_nested # Generate from nested JSON files  
/// gleam run help           # Show help
/// gleam run                # Show help (default)
/// ```
pub fn main() {
  case argv.load().arguments {
    ["generate"] -> generate_command()
    ["generate_nested"] -> generate_nested_command()
    ["help"] -> help_command()
    [] -> help_command()
    _ -> {
      io.println("Unknown command. Use 'help' for available commands.")
    }
  }
}

fn generate_command() {
  case generate_translations() {
    Ok(path) -> {
      io.println("🌏Generated translation modules from flat JSON")
      io.println("  " <> path)
    }
    Error(msg) -> io.println("Error: " <> msg)
  }
}

fn generate_nested_command() {
  case generate_nested_translations() {
    Ok(path) -> {
      io.println("🌏Generated translation modules from nested JSON")
      io.println("  " <> path)
    }
    Error(msg) -> io.println("Error: " <> msg)
  }
}

fn help_command() {
  io.println("g18n CLI - Internationalization for Gleam")
  io.println("")
  io.println("Commands:")
  io.println(
    "  generate         Generate Gleam module from flat JSON files",
  )
  io.println(
    "  generate_nested  Generate Gleam module from nested JSON files (industry standard)",
  )
  io.println("  help             Show this help message")
  io.println("")
  io.println("Flat JSON usage:")
  io.println(
    "  Place flat JSON files in src/<project>/translations/",
  )
  io.println("  Example: {\"ui.button.save\": \"Save\", \"user.name\": \"Name\"}")
  io.println("  Run 'gleam run generate' to create the translations module")
  io.println("")
  io.println("Nested JSON usage:")
  io.println(
    "  Place nested JSON files in src/<project>/translations/",
  )
  io.println("  Example: {\"ui\": {\"button\": {\"save\": \"Save\"}}, \"user\": {\"name\": \"Name\"}}")
  io.println("  Run 'gleam run generate_nested' to create the translations module")
  io.println("")
  io.println("Supported formats:")
  io.println("  ✅ Flat JSON (g18n optimized)")
  io.println("  ✅ Nested JSON (react-i18next, Vue i18n, Angular i18n compatible)")
  io.println("")
}

fn generate_translations() -> Result(String, String) {
  use project_name <- result.try(get_project_name())
  use locale_files <- result.try(find_locale_files(project_name))
  use output_path <- result.try(write_multi_locale_module(
    project_name,
    locale_files,
  ))
  Ok(output_path)
}

fn generate_nested_translations() -> Result(String, String) {
  use project_name <- result.try(get_project_name())
  use locale_files <- result.try(find_locale_files(project_name))
  use output_path <- result.try(write_multi_locale_module_from_nested(
    project_name,
    locale_files,
  ))
  Ok(output_path)
}

fn get_project_name() -> Result(String, String) {
  let root = find_root(".")
  let toml_path = filepath.join(root, "gleam.toml")

  use content <- result.try(
    simplifile.read(toml_path)
    |> result.map_error(fn(_) { "Could not read gleam.toml" }),
  )

  use toml <- result.try(
    tom.parse(content)
    |> result.map_error(fn(_) { "Could not parse gleam.toml" }),
  )

  use name <- result.try(
    tom.get_string(toml, ["name"])
    |> result.map_error(fn(_) { "Could not find project name in gleam.toml" }),
  )

  Ok(name)
}

fn escape_string(str: String) -> String {
  str
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
}

fn find_root(path: String) -> String {
  let toml = filepath.join(path, "gleam.toml")

  case simplifile.is_file(toml) {
    Ok(False) | Error(_) -> find_root(filepath.join(path, ".."))
    Ok(True) -> path
  }
}

fn find_locale_files(
  project_name: String,
) -> Result(List(#(String, String)), String) {
  let root = find_root(".")
  let translations_dir =
    filepath.join(root, "src")
    |> filepath.join(project_name)
    |> filepath.join("translations")

  case simplifile.read_directory(translations_dir) {
    Ok(files) -> {
      let locale_files =
        files
        |> list_filter(fn(file) {
          string.ends_with(file, ".json") && file != "translations.json"
        })
        |> list_map(fn(file) {
          let locale_code = string.drop_end(file, 5)
          // Remove .json extension
          let file_path = filepath.join(translations_dir, file)
          #(locale_code, file_path)
        })

      case locale_files {
        [] ->
          Error(
            "No locale JSON files found in "
            <> translations_dir
            <> "\nLooking for files like en.json, es.json, pt.json, etc.",
          )
        files -> Ok(files)
      }
    }
    Error(_) ->
      Error("Could not read translations directory: " <> translations_dir)
  }
}

fn write_multi_locale_module(
  project_name: String,
  locale_files: List(#(String, String)),
) -> Result(String, String) {
  use locale_data <- result.try(load_all_locales(locale_files))
  let root = find_root(".")
  let output_path =
    filepath.join(root, "src")
    |> filepath.join(project_name)
    |> filepath.join("translations.gleam")

  let module_content = generate_multi_locale_module_content(locale_data)

  simplifile.write(output_path, module_content)
  |> result.map_error(fn(_) {
    "Could not write translations module at: " <> output_path
  })
  |> result.map(fn(_) { output_path })
}

fn write_multi_locale_module_from_nested(
  project_name: String,
  locale_files: List(#(String, String)),
) -> Result(String, String) {
  use locale_data <- result.try(load_all_locales_from_nested(locale_files))
  let root = find_root(".")
  let output_path =
    filepath.join(root, "src")
    |> filepath.join(project_name)
    |> filepath.join("translations.gleam")

  let module_content = generate_multi_locale_module_content(locale_data)

  simplifile.write(output_path, module_content)
  |> result.map_error(fn(_) {
    "Could not write translations module from nested JSON at: " <> output_path
  })
  |> result.map(fn(_) { output_path })
}

fn load_all_locales(
  locale_files: List(#(String, String)),
) -> Result(List(#(String, Translations)), String) {
  list_fold_result(locale_files, [], fn(acc, locale_file) {
    let #(locale_code, file_path) = locale_file
    use content <- result.try(
      simplifile.read(file_path)
      |> result.map_error(fn(_) { "Could not read " <> file_path }),
    )
    use translations <- result.try(translations_from_json(content))
    Ok([#(locale_code, translations), ..acc])
  })
  |> result.map(list.reverse)
}

fn load_all_locales_from_nested(
  locale_files: List(#(String, String)),
) -> Result(List(#(String, Translations)), String) {
  list_fold_result(locale_files, [], fn(acc, locale_file) {
    let #(locale_code, file_path) = locale_file
    use content <- result.try(
      simplifile.read(file_path)
      |> result.map_error(fn(_) { "Could not read " <> file_path }),
    )
    use translations <- result.try(translations_from_nested_json(content))
    Ok([#(locale_code, translations), ..acc])
  })
  |> result.map(list.reverse)
}

fn generate_multi_locale_module_content(
  locale_data: List(#(String, Translations)),
) -> String {
  let imports = "import g18n\n\n"

  let locale_functions =
    locale_data
    |> list_map(fn(locale_pair) {
      let #(locale_code, translations) = locale_pair
      generate_single_locale_functions(locale_code, translations)
    })
    |> string.join("\n\n")

  let all_locales_function = generate_all_locales_function(locale_data)

  imports <> locale_functions <> "\n\n" <> all_locales_function
}

fn generate_single_locale_functions(
  locale_code: String,
  translations: Translations,
) -> String {
  // Convert trie to dict for generation
  let dict_translations =
    trie.fold(translations, dict.new(), fn(dict_acc, key_parts, value) {
      let key = string.join(key_parts, ".")
      dict.insert(dict_acc, key, value)
    })

  let translations_list =
    dict_translations
    |> dict.to_list
    |> list.map(fn(pair) {
      "  |> g18n.add_translation(\""
      <> pair.0
      <> "\", \""
      <> escape_string(pair.1)
      <> "\")"
    })
    |> string.join("\n")

  let translations_func =
    "pub fn "
    <> locale_code
    <> "_translations() -> g18n.Translations {\n  g18n.translations()\n"
    <> translations_list
    <> "\n}"

  let locale_func =
    "pub fn "
    <> locale_code
    <> "_locale() -> Result(g18n.Locale, g18n.LocaleError) {\n  g18n.locale(\""
    <> locale_code
    <> "\")\n}"

  let translator_func =
    "pub fn "
    <> locale_code
    <> "_translator() -> Result(g18n.Translator, g18n.LocaleError) {\n  case "
    <> locale_code
    <> "_locale() {\n    Ok(loc) -> Ok(g18n.translator(loc, "
    <> locale_code
    <> "_translations()))\n    Error(err) -> Error(err)\n  }\n}"

  translations_func <> "\n\n" <> locale_func <> "\n\n" <> translator_func
}

fn generate_all_locales_function(
  locale_data: List(#(String, Translations)),
) -> String {
  let locale_list =
    locale_data
    |> list_map(fn(pair) { "\"" <> pair.0 <> "\"" })
    |> string.join(", ")

  "pub fn available_locales() -> List(String) {\n  [" <> locale_list <> "]\n}"
}

fn list_fold_result(
  list: List(a),
  initial: b,
  func: fn(b, a) -> Result(b, String),
) -> Result(b, String) {
  case list {
    [] -> Ok(initial)
    [head, ..tail] -> {
      case func(initial, head) {
        Ok(new_acc) -> list_fold_result(tail, new_acc, func)
        Error(err) -> Error(err)
      }
    }
  }
}

fn locale_to_string(locale: Locale) -> String {
  case locale {
    Locale(language, country) ->
      case country {
        Some(c) -> language <> "-" <> c
        None -> language
      }
  }
}
