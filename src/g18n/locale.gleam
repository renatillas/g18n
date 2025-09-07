import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import splitter

pub opaque type Locale {
  Locale(language: String, region: Option(String))
}

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

pub type LocaleError {
  InvalidLanguage(reason: String)
  InvalidLocale(reason: String)
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
type TextDirection {
  LTR
  // Left-to-Right (English, Spanish, German, etc.)
  RTL
  // Right-to-Left (Arabic, Hebrew, Persian, etc.)
}

@internal
pub fn locale_plural_rule(locale: Locale) -> PluralRules {
  case locale {
    Locale("en", _) -> english_plural_rule
    Locale("es", _) -> spanish_plural_rule
    Locale("pt", _) -> portuguese_plural_rule
    Locale("fr", _) -> french_plural_rule
    Locale("de", _) -> german_plural_rule
    Locale("it", _) -> italian_plural_rule
    Locale("ru", _) -> russian_plural_rule
    Locale("ar", _) -> arabic_plural_rule
    Locale("zh", _) -> chinese_plural_rule
    Locale("ja", _) -> japanese_plural_rule
    Locale("ko", _) -> korean_plural_rule
    Locale("hi", _) -> hindi_plural_rule
    _ -> english_plural_rule
    // Fallback to English for unsupported languages
  }
}

@internal
pub fn ordinal_rule(locale: Locale, position: Int) -> OrdinalRule {
  case locale {
    Locale("en", _) -> english_ordinal_rule(position)
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

@internal
pub fn ordinal_key(base_key: String, ordinal_rule: OrdinalRule) -> String {
  case ordinal_rule {
    First -> base_key <> ".first"
    Second -> base_key <> ".second"
    Third -> base_key <> ".third"
    Nth -> base_key <> ".nth"
  }
}

@internal
pub fn ordinal_suffix(locale: Locale, position: Int) -> String {
  case locale {
    Locale("en", _) -> english_ordinal_suffix(position)
    _ -> int.to_string(position)
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

@internal
pub fn plural_key(
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

fn english_plural_rule(count: Int) -> PluralRule {
  case count {
    1 -> One
    _ -> Other
  }
}

fn portuguese_plural_rule(count: Int) -> PluralRule {
  case count {
    0 -> Zero
    1 -> One
    _ -> Other
  }
}

fn russian_plural_rule(count: Int) -> PluralRule {
  let mod_10 = count % 10
  let mod_100 = count % 100

  case mod_10, mod_100 {
    1, n if n != 11 -> One
    v, n if v >= 2 && v <= 4 && n < 12 || n > 14 -> Few
    _, _ -> Many
  }
}

fn spanish_plural_rule(count: Int) -> PluralRule {
  case count {
    1 -> One
    _ -> Other
  }
}

fn french_plural_rule(count: Int) -> PluralRule {
  case count {
    0 | 1 -> One
    _ -> Other
  }
}

fn german_plural_rule(count: Int) -> PluralRule {
  case count {
    1 -> One
    _ -> Other
  }
}

fn italian_plural_rule(count: Int) -> PluralRule {
  case count {
    1 -> One
    _ -> Other
  }
}

fn arabic_plural_rule(count: Int) -> PluralRule {
  case count {
    0 -> Zero
    1 -> One
    2 -> Two
    n if n >= 3 && n <= 10 -> Few
    n if n >= 11 && n <= 99 -> Many
    _ -> Other
  }
}

fn chinese_plural_rule(_count: Int) -> PluralRule {
  Other
}

fn japanese_plural_rule(_count: Int) -> PluralRule {
  Other
}

fn korean_plural_rule(_count: Int) -> PluralRule {
  Other
}

fn hindi_plural_rule(count: Int) -> PluralRule {
  case count {
    0 | 1 -> One
    _ -> Other
  }
}

/// Create a new locale from a locale code string.
/// Supports formats like "en", "en-US", "pt-BR".
/// 
/// ## Examples
/// ```gleam
/// let assert Ok(en) = locale.new("en")
/// let assert Ok(en_us) = locale.new("en-US")
/// let assert Error(_) = locale.new("invalid")
/// ```
pub fn new(locale_code: String) -> Result(Locale, LocaleError) {
  parse(locale_code)
}

/// Convert a locale back to its string representation.
/// 
/// ## Examples
/// ```gleam
/// let assert Ok(locale) = g18n.locale("en-US")
/// g18n.locale_string(locale) // "en-US"
/// ```
pub fn to_string(locale: Locale) -> String {
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
pub fn language(locale: Locale) -> String {
  locale.language
}

/// Extract the region code from a locale.
/// 
/// ## Examples
/// ```gleam
/// let assert Ok(locale) = g18n.locale("en-US")
/// g18n.locale_region(locale) // Some("US")
/// ```
pub fn region(locale: Locale) -> Option(String) {
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
pub fn match_language(locale1: Locale, locale2: Locale) -> Bool {
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
pub fn exact_match(locale1: Locale, locale2: Locale) -> Bool {
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
pub fn language_only(locale: Locale) -> Locale {
  Locale(language: locale.language, region: None)
}

fn text_direction(locale: Locale) -> TextDirection {
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
  case text_direction(locale) {
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
  case text_direction(locale) {
    RTL -> "rtl"
    LTR -> "ltr"
  }
}

fn parse(locale_code: String) -> Result(Locale, LocaleError) {
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
  available: List(Locale),
  preferred: List(Locale),
) -> Result(Locale, Nil) {
  use <- bool.guard(list.is_empty(available), Error(Nil))
  use <- bool.guard(list.is_empty(preferred), list.first(available))
  let assert [first, ..rest] = preferred
  case find_exact_match(available, first) {
    Ok(match) -> Ok(match)
    Error(Nil) -> {
      // Try language match
      case find_language_match(available, first) {
        Some(match) -> Ok(match)
        None -> {
          // Try region fallback (en-US -> en)
          case find_region_fallback(available, first) {
            Some(match) -> Ok(match)
            None -> {
              negotiate_locale(available, rest)
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
pub fn parse_accept_language(header: String) -> List(Locale) {
  header
  |> string.split(",")
  |> list.map(string.trim)
  |> list.filter(fn(s) { s != "" })
  |> list.map(fn(lang_spec) {
    case string.split(lang_spec, ";") {
      [] -> Error(InvalidLocale("Empty language specification"))
      [locale_code] -> new(locale_code)
      [locale_code, ..] -> new(locale_code)
    }
  })
  |> result.values
}

@internal
pub fn locale_quality_score(preferred: Locale, available: Locale) -> Float {
  case exact_match(preferred, available) {
    True -> 1.0
    False ->
      case match_language(preferred, available) {
        True -> 0.8
        False -> 0.0
      }
  }
}

fn find_exact_match(
  available: List(Locale),
  preferred: Locale,
) -> Result(Locale, Nil) {
  list.find(available, exact_match(_, preferred))
}

fn find_language_match(
  available: List(Locale),
  preferred: Locale,
) -> Option(Locale) {
  case list.find(available, match_language(_, preferred)) {
    Ok(locale) -> Some(locale)
    Error(Nil) -> None
  }
}

fn find_region_fallback(
  available: List(Locale),
  preferred: Locale,
) -> Option(Locale) {
  let lang_only = language_only(preferred)
  case list.find(available, exact_match(_, lang_only)) {
    Ok(locale) -> Some(locale)
    Error(Nil) -> None
  }
}
