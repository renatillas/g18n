import g18n/internal/po
import g18n/locale
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/string
import gleam/time/calendar
import gleam_community/maths
import splitter
import trie

/// A translator that combines a locale with translations and optional fallback support.
/// 
/// This is the core type for performing translations. It holds the primary locale and translations,
/// plus optional fallback locale and translations for when keys are missing in the primary set.
///
/// ## Examples
/// ```gleam
/// let assert Ok(en_locale) = locale.new("en")
/// let translations = g18n.new_translations()
///   |> g18n.add_translation("hello", "Hello")
/// let translator = g18n.new_translator(en_locale, translations)
/// 
/// // With fallback
/// let translator_with_fallback = translator
///   |> g18n.with_fallback(fallback_locale, fallback_translations)
/// ```
pub opaque type Translator {
  Translator(
    locale: locale.Locale,
    translations: Translations,
    fallback_locale: Option(locale.Locale),
    fallback_translations: Option(Translations),
  )
}

/// Parameters for string formatting and interpolation.
///
/// A dictionary mapping parameter names to their string values for use in
/// translation templates like "Hello {name}!" or "You have {count} items".
///
/// ## Examples
/// ```gleam
/// let params = g18n.new_format_params()
///   |> g18n.add_param("name", "Alice")
///   |> g18n.add_param("count", "5")
/// ```
pub type FormatParams =
  Dict(String, String)

/// Context for disambiguating translations with multiple meanings.
///
/// Used to distinguish between different meanings of the same word or phrase.
/// For example, "bank" could refer to a financial institution or a riverbank.
///
/// ## Examples
/// ```gleam
/// g18n.translate_with_context(translator, "bank", g18n.Context("financial"))
/// // Returns "financial institution"
/// 
/// g18n.translate_with_context(translator, "bank", g18n.Context("river"))
/// // Returns "riverbank"
/// 
/// g18n.translate_with_context(translator, "bank", g18n.NoContext)
/// // Returns default "bank" translation
/// ```
pub type TranslationContext {
  /// No specific context - use the default translation
  NoContext
  /// Specific context to disambiguate meaning
  Context(String)
}

/// Container for translation key-value pairs with hierarchical organization.
///
/// Uses an efficient trie data structure for fast lookups and supports
/// hierarchical keys with dot notation like "ui.button.save".
/// This is an opaque type - use the provided functions to interact with it.
///
/// ## Examples
/// ```gleam
/// let translations = g18n.new_translations()
///   |> g18n.add_translation("ui.button.save", "Save")
///   |> g18n.add_translation("ui.button.cancel", "Cancel")
///   |> g18n.add_context_translation("bank", "financial", "Bank")
/// ```
pub opaque type Translations {
  Translations(translations: trie.Trie(String, String))
}

/// Duration units for relative time formatting.
///
/// Used to express time differences in human-readable formats like
/// "2 hours ago" or "in 3 days".
///
/// ## Examples
/// ```gleam
/// g18n.format_relative_time(translator, g18n.Hours(2), g18n.Past)
/// // "2 hours ago"
/// 
/// g18n.format_relative_time(translator, g18n.Days(3), g18n.Future)
/// // "in 3 days"
/// ```
pub type RelativeDuration {
  Seconds(Int)
  Minutes(Int)
  Hours(Int)
  Days(Int)
  Weeks(Int)
  Months(Int)
  Years(Int)
}

/// Direction for relative time formatting.
///
/// Indicates whether the time is in the past or future relative to now.
///
/// ## Examples
/// ```gleam
/// g18n.format_relative_time(translator, g18n.Hours(2), g18n.Past)
/// // "2 hours ago"
/// 
/// g18n.format_relative_time(translator, g18n.Hours(2), g18n.Future)
/// // "in 2 hours"
/// ```
pub type TimeRelative {
  /// Time in the past (e.g., "2 hours ago")
  Past
  /// Time in the future (e.g., "in 2 hours")
  Future
}

/// Formatting styles for date and time display.
///
/// Provides different levels of detail and formats for displaying dates and times,
/// from compact short formats to verbose full formats with day names.
///
/// ## Examples
/// ```gleam
/// let date = calendar.Date(2024, calendar.January, 15)
/// 
/// g18n.format_date(translator, date, g18n.Short)
/// // "1/15/24"
/// 
/// g18n.format_date(translator, date, g18n.Full)
/// // "Monday, January 15, 2024"
/// 
/// g18n.format_date(translator, date, g18n.Custom("YYYY-MM-DD"))
/// // "2024-01-15"
/// ```
pub type DateTimeFormat {
  /// Compact format: 12/25/23, 3:45 PM
  Short
  /// Medium format: Dec 25, 2023, 3:45:30 PM
  Medium
  /// Long format: December 25, 2023, 3:45:30 PM GMT
  Long
  /// Full format: Monday, December 25, 2023, 3:45:30 PM GMT
  Full
  /// Custom format string: "YYYY-MM-DD HH:mm:ss"
  Custom(String)
}

/// Number formatting styles for locale-aware number display.
///
/// Supports various number formats including decimals, currency, percentages,
/// scientific notation, and compact notation for large numbers.
///
/// ## Examples
/// ```gleam
/// g18n.format_number(translator, 1234.56, g18n.Decimal(2))
/// // "1,234.56" (English) or "1.234,56" (German)
/// 
/// g18n.format_number(translator, 1234.56, g18n.Currency("USD", 2))
/// // "$1,234.56"
/// 
/// g18n.format_number(translator, 0.75, g18n.Percentage(1))
/// // "75.0%"
/// 
/// g18n.format_number(translator, 1000000.0, g18n.Compact)
/// // "1.0M"
/// ```
pub type NumberFormat {
  /// Decimal format with specified precision
  Decimal(precision: Int)
  /// Currency format with currency code and precision
  Currency(currency_code: String, precision: Int)
  /// Percentage format with precision
  Percentage(precision: Int)
  /// Scientific notation with precision
  Scientific(precision: Int)
  /// Compact format: 1.2K, 3.4M, 1.2B
  Compact
}

// Locale Functions

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
pub fn context_variants(
  translations: Translations,
  base_key: String,
) -> List(#(String, String)) {
  trie.fold(translations.translations, [], fn(acc, key_parts, value) {
    let full_key = string.join(key_parts, ".")
    case string.starts_with(full_key, base_key) {
      True -> [#(full_key, value), ..acc]
      False -> acc
    }
  })
  |> list.reverse
}

// Translation Management
/// Create a new empty translations container.
///
/// ## Examples
/// ```gleam
/// let translations = g18n.new()
///   |> g18n.add_translation("hello", "Hello")
///   |> g18n.add_translation("goodbye", "Goodbye")
/// ```
pub fn new_translations() -> Translations {
  Translations(trie.new())
}

/// Add a translation key-value pair to a translations container.
///
/// Supports hierarchical keys using dot notation for organization.
///
/// ## Examples
/// ```gleam
/// let translations = g18n.new()
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
  Translations(trie.insert(translations.translations, key_parts, value))
}

/// Get all translation keys that start with a given prefix.
///
/// Useful for finding all keys within a specific namespace.
///
/// ## Examples
/// ```gleam
/// let translations = g18n.new()
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
  trie.fold(translations.translations, [], fn(acc, key_parts, _value) {
    let full_key = string.join(key_parts, ".")
    case has_prefix(key_parts, prefix_parts) {
      True -> [full_key, ..acc]
      False -> acc
    }
  })
  |> list.reverse
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
  |> list.map(fn(match) {
    case match.submatches {
      [Some(placeholder)] -> placeholder
      _ -> ""
    }
  })
  |> list.filter(fn(placeholder) { placeholder != "" })
}

/// Errors found during translation validation.
///
/// Represents different types of issues that can be found when validating
/// translations between different locales, such as missing keys, parameter
/// mismatches, or incomplete plural forms.
///
/// ## Examples
/// ```gleam
/// let report = g18n.validate_translations(primary, target, es_locale)
/// list.each(report.errors, fn(error) {
///   case error {
///     g18n.MissingTranslation(key, locale) -> 
///       io.println("Missing: " <> key <> " for " <> locale.to_string(locale))
///     g18n.MissingParameter(key, param, locale) ->
///       io.println("Missing param {" <> param <> "} in " <> key)
///     _ -> Nil
///   }
/// })
/// ```
pub type ValidationError {
  /// Translation key exists in primary but missing in target locale
  MissingTranslation(key: String, locale: locale.Locale)
  /// Required parameter is missing from translation template
  MissingParameter(key: String, param: String, locale: locale.Locale)
  /// Parameter exists in translation but not expected
  UnusedParameter(key: String, param: String, locale: locale.Locale)
  /// Plural form is incomplete (missing required plural variants)
  InvalidPluralForm(
    key: String,
    missing_forms: List(String),
    locale: locale.Locale,
  )
  /// Translation key exists but has empty/blank value
  EmptyTranslation(key: String, locale: locale.Locale)
}

/// Complete validation report with errors, warnings, and coverage statistics.
///
/// Provides comprehensive analysis of translation completeness and quality
/// between a primary locale (e.g., English) and target locales.
///
/// ## Examples
/// ```gleam
/// let report = g18n.validate_translations(primary, target, es_locale)
/// 
/// io.println("Coverage: " <> float.to_string(report.coverage * 100.0) <> "%")
/// io.println("Errors: " <> int.to_string(list.length(report.errors)))
/// io.println("Translated: " <> int.to_string(report.translated_keys) 
///   <> "/" <> int.to_string(report.total_keys))
/// ```
pub type ValidationReport {
  ValidationReport(
    /// List of validation errors found
    errors: List(ValidationError),
    /// List of validation warnings (non-critical issues)  
    warnings: List(ValidationError),
    /// Total number of keys in primary translations
    total_keys: Int,
    /// Number of keys successfully translated in target
    translated_keys: Int,
    /// Translation coverage as decimal (0.0 to 1.0)
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
/// let primary = g18n.new()
///   |> g18n.add_translation("welcome", "Welcome {name}!")
///   |> g18n.add_translation("items.one", "1 item")
///   |> g18n.add_translation("items.other", "{count} items")
/// 
/// let target = g18n.new()
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
  target_locale: locale.Locale,
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
  locale: locale.Locale,
) -> List(ValidationError) {
  let key_parts = string.split(key, ".")
  case trie.get(translations.translations, key_parts) {
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
pub fn translation_coverage(
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

fn get_all_translation_keys(translations: Translations) -> List(String) {
  trie.fold(translations.translations, [], fn(acc, key_parts, _value) {
    let key = string.join(key_parts, ".")
    [key, ..acc]
  })
}

fn find_missing_translations(
  primary_keys: List(String),
  target_keys: List(String),
  locale: locale.Locale,
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
  target_locale: locale.Locale,
) -> List(ValidationError) {
  let target_keys = get_all_translation_keys(target_translations)

  list.flat_map(target_keys, fn(key) {
    let key_parts = string.split(key, ".")
    case
      trie.get(primary_translations.translations, key_parts),
      trie.get(target_translations.translations, key_parts)
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
  locale: locale.Locale,
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
  locale: locale.Locale,
) -> List(ValidationError) {
  let required_forms = case locale.language(locale) {
    "en" -> ["one", "other"]
    "pt" -> ["zero", "one", "other"]
    "ru" -> ["one", "few", "many"]
    _ -> ["one", "other"]
  }

  let missing_forms =
    list.filter(required_forms, fn(form) {
      let key_parts = string.split(base_key <> "." <> form, ".")
      case trie.get(translations.translations, key_parts) {
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
  locale: locale.Locale,
) -> List(ValidationError) {
  trie.fold(translations.translations, [], fn(acc, key_parts, value) {
    let key = string.join(key_parts, ".")
    case string.trim(value) {
      "" -> [EmptyTranslation(key, locale), ..acc]
      _ -> acc
    }
  })
}

fn count_translations(translations: Translations) -> Int {
  trie.fold(translations.translations, 0, fn(count, _key, _value) { count + 1 })
}

fn format_validation_errors(errors: List(ValidationError)) -> String {
  errors
  |> list.map(fn(error) {
    case error {
      MissingTranslation(key, locale) ->
        "  - Missing translation for '"
        <> key
        <> "' in "
        <> locale.to_string(locale)
      MissingParameter(key, param, locale) ->
        "  - Missing parameter '{"
        <> param
        <> "}' in '"
        <> key
        <> "' ("
        <> locale.to_string(locale)
        <> ")"
      UnusedParameter(key, param, locale) ->
        "  - Unused parameter '{"
        <> param
        <> "}' in '"
        <> key
        <> "' ("
        <> locale.to_string(locale)
        <> ")"
      InvalidPluralForm(key, forms, locale) ->
        "  - Missing plural forms "
        <> string.join(forms, with: ", ")
        <> " for '"
        <> key
        <> "' in "
        <> locale.to_string(locale)
      EmptyTranslation(key, locale) ->
        "  - Empty translation for '"
        <> key
        <> "' in "
        <> locale.to_string(locale)
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
pub fn translations_from_json(json_string: String) -> Result(Translations, Nil) {
  case json.parse(json_string, decode.dict(decode.string, decode.string)) {
    Ok(dict_result) -> {
      // Convert dict to trie
      let trie_result =
        dict.fold(dict_result, new_translations(), fn(translations, key, value) {
          let key_parts = string.split(key, ".")
          Translations(trie.insert(translations.translations, key_parts, value))
        })
      Ok(trie_result)
    }
    Error(_) -> Error(Nil)
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
    trie.fold(
      translations.translations,
      dict.new(),
      fn(dict_acc, key_parts, value) {
        let key = string.join(key_parts, ".")
        dict.insert(dict_acc, key, value)
      },
    )

  dict_translations
  |> dict.to_list
  |> list.map(fn(pair) { #(pair.0, json.string(pair.1)) })
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
  case json.parse(json_string, decode.dynamic) {
    Ok(dynamic_result) -> {
      case
        decode.run(dynamic_result, decode.dict(decode.string, decode.dynamic))
      {
        Ok(dict_result) -> {
          flatten_json_object(dict_result, "")
          |> dict.fold(new_translations(), fn(trie, key, value) {
            string.split(key, ".")
            |> trie.insert(trie.translations, _, value)
            |> Translations
          })
          |> Ok
        }
        Error(_) -> Error("Failed to decode as dictionary")
      }
    }
    Error(_) -> Error("Failed to parse nested JSON")
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

/// Create translations from a PO file content string.
/// 
/// Parses PO file format and converts entries to the internal trie structure.
/// Supports msgid/msgstr pairs, contexts (msgctxt), multiline strings,
/// and standard PO escape sequences.
/// 
/// ## Examples
/// ```gleam
/// let po_content = "
/// msgid \"hello\"
/// msgstr \"Hello\"
/// 
/// msgctxt \"greeting\"
/// msgid \"hello\"
/// msgstr \"Hi there\"
/// "
/// let assert Ok(translations) = g18n.translations_from_po(po_content)
/// ```
pub fn translations_from_po(po_content: String) -> Result(Translations, String) {
  case po.parse_po_content(po_content) {
    Ok(entries) -> {
      let translation_dict = po.entries_to_translations(entries)
      let trie_result =
        dict.fold(
          translation_dict,
          new_translations(),
          fn(translations, key, value) {
            let key_parts = string.split(key, ".")
            Translations(trie.insert(
              translations.translations,
              key_parts,
              value,
            ))
          },
        )
      Ok(trie_result)
    }
    Error(po.InvalidFormat(msg)) -> Error("Invalid PO format: " <> msg)
    Error(po.UnexpectedEof) -> Error("Unexpected end of file")
    Error(po.InvalidEscapeSequence(seq)) ->
      Error("Invalid escape sequence: " <> seq)
    Error(po.MissingMsgid) -> Error("Missing msgid")
    Error(po.MissingMsgstr) -> Error("Missing msgstr")
  }
}

/// Convert translations to PO file format.
/// 
/// Exports the internal trie structure to standard PO file format with
/// msgid/msgstr pairs. Context translations (those with '@' in the key)
/// are exported with msgctxt fields.
/// 
/// ## Examples
/// ```gleam
/// let translations = g18n.new_translations()
///   |> g18n.add_translation("hello", "Hello")
///   |> g18n.add_context_translation("hello", "greeting", "Hi there")
/// let po_content = g18n.translations_to_po(translations)
/// ```
pub fn translations_to_po(translations: Translations) -> String {
  let entries =
    trie.fold(translations.translations, [], fn(acc, key_parts, value) {
      let key = string.join(key_parts, ".")
      case string.split_once(key, "@") {
        Ok(#(msgid, context)) -> {
          let entry =
            po.PoEntry(
              msgid: msgid,
              msgstr: value,
              msgid_plural: None,
              msgstr_plural: [],
              msgctxt: Some(context),
              comments: [],
              references: [],
              flags: [],
            )
          [entry, ..acc]
        }
        Error(Nil) -> {
          let entry =
            po.PoEntry(
              msgid: key,
              msgstr: value,
              msgid_plural: None,
              msgstr_plural: [],
              msgctxt: None,
              comments: [],
              references: [],
              flags: [],
            )
          [entry, ..acc]
        }
      }
    })

  entries
  |> list.reverse
  |> list.map(po_entry_to_string)
  |> string.join("\n\n")
}

fn po_entry_to_string(entry: po.PoEntry) -> String {
  let parts = []

  // Add comments
  let parts =
    list.fold(entry.comments, parts, fn(acc, comment) {
      ["# " <> comment, ..acc]
    })

  // Add references  
  let parts =
    list.fold(entry.references, parts, fn(acc, reference) {
      ["#: " <> reference, ..acc]
    })

  // Add flags
  let parts =
    list.fold(entry.flags, parts, fn(acc, flag) { ["#, " <> flag, ..acc] })

  // Add msgctxt if present
  let parts = case entry.msgctxt {
    Some(context) -> ["msgctxt " <> escape_po_string(context), ..parts]
    None -> parts
  }

  // Add msgid and msgstr (or plural forms)
  let parts = case entry.msgstr_plural {
    [] -> {
      // Regular entry
      [
        "msgstr " <> escape_po_string(entry.msgstr),
        "msgid " <> escape_po_string(entry.msgid),
        ..parts
      ]
    }
    plural_forms -> {
      // Plural entry - add msgstr[n] forms
      let msgstr_parts =
        list.index_fold(plural_forms, [], fn(acc, form, index) {
          [
            "msgstr[" <> int.to_string(index) <> "] " <> escape_po_string(form),
            ..acc
          ]
        })
      let msgid_parts = case entry.msgid_plural {
        Some(plural_msgid) -> [
          "msgid_plural " <> escape_po_string(plural_msgid),
          "msgid " <> escape_po_string(entry.msgid),
        ]
        None -> ["msgid " <> escape_po_string(entry.msgid)]
      }
      list.flatten([list.reverse(msgstr_parts), msgid_parts, parts])
    }
  }

  parts
  |> list.reverse
  |> string.join("\n")
}

fn escape_po_string(input: String) -> String {
  "\""
  <> string.replace(input, "\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\t", "\\t")
  |> string.replace("\r", "\\r")
  <> "\""
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
        flatten_json_object(nested_dict, current_key)
        |> dict.fold(acc, dict.insert)
      }
      Error(_) -> {
        case decode.run(value, decode.string) {
          Ok(str_value) -> dict.insert(acc, current_key, str_value)
          Error(_) -> acc
        }
      }
    }
  })
}

// Convert trie directly to nested JSON structure
fn trie_to_nested_json(translations: Translations) -> json.Json {
  // First convert trie to flat dictionary for easier processing
  let flat_dict =
    trie.fold(translations.translations, dict.new(), fn(acc, key_parts, value) {
      let flat_key = string.join(key_parts, ".")
      dict.insert(acc, flat_key, value)
    })

  // Then build nested structure from flat keys
  build_nested_from_flat(flat_dict)
}

// Build nested JSON structure from flat dictionary  
fn build_nested_from_flat(flat_dict: Dict(String, String)) -> json.Json {
  // Create a mutable state structure to track nested paths
  flat_dict
  |> dict.to_list
  |> build_nested_recursive(dict.new())
  |> dict.to_list
  |> json.object
}

// Recursively build nested structure by processing flat keys
fn build_nested_recursive(
  flat_pairs: List(#(String, String)),
  acc: Dict(String, json.Json),
) -> Dict(String, json.Json) {
  case flat_pairs {
    [] -> acc
    [#(flat_key, value), ..rest] -> {
      let key_parts = string.split(flat_key, ".")
      let updated_acc = set_nested_value(acc, key_parts, json.string(value))
      build_nested_recursive(rest, updated_acc)
    }
  }
}

// Set a value in nested structure, creating intermediate objects as needed
fn set_nested_value(
  dict_acc: Dict(String, json.Json),
  key_parts: List(String),
  value: json.Json,
) -> Dict(String, json.Json) {
  case key_parts {
    [] -> dict_acc
    [single_key] -> dict.insert(dict_acc, single_key, value)
    [first_key, ..remaining_keys] -> {
      case dict.get(dict_acc, first_key) {
        Ok(existing_json) -> extract_json_dict(existing_json)
        Error(_) -> dict.new()
      }
      |> set_nested_value(remaining_keys, value)
      |> dict.to_list()
      |> json.object
      |> dict.insert(dict_acc, first_key, _)
    }
  }
}

// Extract a dictionary from JSON using decode.recursive
fn extract_json_dict(json_val: json.Json) -> Dict(String, json.Json) {
  let json_str = json.to_string(json_val)

  case json.parse(json_str, decode.dict(decode.string, json_value_decoder())) {
    Ok(parsed_dict) -> parsed_dict
    Error(_) -> dict.new()
  }
}

// Recursive decoder for JSON values that can be either strings or nested objects
fn json_value_decoder() -> decode.Decoder(json.Json) {
  use <- decode.recursive
  decode.one_of(decode.string |> decode.map(json.string), [
    decode.dict(decode.string, json_value_decoder())
    |> decode.map(fn(dict_val) { dict.to_list(dict_val) |> json.object }),
  ])
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
pub fn new_translator(
  locale: locale.Locale,
  translations: Translations,
) -> Translator {
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
  fallback_locale: locale.Locale,
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
/// g18n.t(translator, "ui.button.save")
/// // "Save"
/// 
/// g18n.t(translator, "user.greeting") 
/// // "Hello"
/// 
/// g18n.t(translator, "missing.key")
/// // "missing.key" (fallback to key)
/// ```
pub fn translate(translator: Translator, key: String) -> String {
  let key_parts = string.split(key, ".")
  case trie.get(translator.translations.translations, key_parts) {
    Ok(translation) -> translation
    Error(Nil) -> fallback_translation(translator, key_parts, key)
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
/// g18n.t_with_params(translator, "user.welcome", params)
/// // "Welcome Alice!"
/// 
/// g18n.t_with_params(translator, "user.messages", params)
/// // "You have 5 new messages"
/// ```
pub fn translate_with_params(
  translator: Translator,
  key: String,
  params params: FormatParams,
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
/// g18n.t_with_context(translator, "may", NoContext)         // "may"
/// g18n.t_with_context(translator, "may", Context("month"))  // "May"  
/// g18n.t_with_context(translator, "may", Context("permission")) // "allowed to"
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
  let language = translator.locale
  let plural_rule = locale.locale_plural_rule(language)
  let plural_key = locale.plural_key(key, count, plural_rule)
  let template = translate(translator, plural_key)

  // Automatically substitute the {count} parameter
  let params = dict.new() |> dict.insert("count", int.to_string(count))
  format_string(template, params)
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
pub fn translate_plural_with_params(
  translator: Translator,
  key: String,
  count: Int,
  params: FormatParams,
) -> String {
  let language = translator.locale
  let plural_rule = locale.locale_plural_rule(language)
  let plural_key = locale.plural_key(key, count, plural_rule)
  let template = translate(translator, plural_key)

  // Add count parameter and merge with provided params
  let all_params = params |> dict.insert("count", int.to_string(count))
  format_string(template, all_params)
}

/// Get the locale from a translator.
///
/// ## Examples
/// ```gleam
/// let assert Ok(locale) = g18n.locale("en-US")
/// let translator = g18n.translator(locale, g18n.translations())
/// g18n.get_locale(translator) // Locale(language: "en", region: Some("US"))
/// ```
pub fn locale(translator: Translator) -> locale.Locale {
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
pub fn fallback_locale(translator: Translator) -> Option(locale.Locale) {
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
pub fn translations(translator: Translator) -> Translations {
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
pub fn fallback_translations(translator: Translator) -> Option(Translations) {
  translator.fallback_translations
}

fn fallback_translation(
  translator: Translator,
  key_parts: List(String),
  original_key: String,
) -> String {
  case translator.fallback_translations {
    Some(fallback_trans) -> {
      case trie.get(fallback_trans.translations, key_parts) {
        Ok(translation) -> translation
        Error(Nil) -> original_key
      }
    }
    None -> original_key
  }
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
pub fn namespace(
  translator: Translator,
  namespace: String,
) -> List(#(String, String)) {
  let prefix_parts = string.split(namespace, ".")
  trie.fold(translator.translations.translations, [], fn(acc, key_parts, value) {
    let full_key = string.join(key_parts, ".")
    case has_prefix(key_parts, prefix_parts) {
      True -> [#(full_key, value), ..acc]
      False -> acc
    }
  })
  |> list.reverse
}

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
  let language = translator.locale
  let ordinal_rule = locale.ordinal_rule(language, position)
  let ordinal_key = locale.ordinal_key(key, ordinal_rule)
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
    |> dict.insert(
      "ordinal",
      locale.ordinal_suffix(translator.locale, position),
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
/// g18n.t_range_with_params(en_translator, "content", 1, 5, params)
/// // Template: "Reading {type} {from} to {to} ({total} total)"
/// // Result: "Reading chapters 1 to 5 (5 total)"
/// 
/// g18n.t_range_with_params(en_translator, "content", 3, 3, params) 
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
  let language = translator |> locale |> locale.language
  case format {
    Decimal(precision) -> decimal(number, precision, language)
    Currency(currency_code, precision) ->
      currency(number, currency_code, precision, language)
    Percentage(precision) -> percentage(number, precision, language)
    Scientific(precision) -> scientific(number, precision)
    Compact -> compact(number, language)
  }
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
  let language = translator |> locale |> locale.language
  case format {
    Short -> date_short(date, language)
    Medium -> date_medium(date, language)
    Long -> date_long(date, language)
    Full -> date_full(date, language)
    Custom(pattern) -> date_custom(date, pattern)
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
  let language = translator |> locale |> locale.language
  case format {
    Short -> time_short(time, language)
    Medium -> time_medium(time, language)
    Long -> time_long(time, language)
    Full -> time_full(time, language)
    Custom(pattern) -> time_custom(time, pattern)
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
  let language = translator |> locale |> locale.language
  case format {
    Short -> datetime_short(date, time, language)
    Medium -> datetime_medium(date, time, language)
    Long -> datetime_long(date, time, language)
    Full -> datetime_full(date, time, language)
    Custom(pattern) -> datetime_custom(date, time, pattern)
  }
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
  let language = translator |> locale |> locale.language
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

fn decimal(number: Float, precision: Int, language: String) -> String {
  let decimal_separator = decimal_separator(language)
  let thousands_separator = thousands_separator(language)

  let formatted_number = case precision {
    0 -> number |> float.round |> int.to_string
    _ -> {
      // Format to exact precision by splitting and padding
      let base_number = float.to_precision(number, precision) |> float.to_string
      case string.split(base_number, ".") {
        [integer_part] -> integer_part <> "." <> string.repeat("0", precision)
        [integer_part, decimal_part] -> {
          let padded_decimal = case string.length(decimal_part) < precision {
            True ->
              decimal_part
              <> string.repeat("0", precision - string.length(decimal_part))
            False -> string.slice(decimal_part, 0, precision)
          }
          integer_part <> "." <> padded_decimal
        }
        _ -> base_number
      }
    }
  }

  add_thousands_separators(
    formatted_number,
    decimal_separator,
    thousands_separator,
  )
}

fn currency(
  number: Float,
  currency_code: String,
  precision: Int,
  language: String,
) -> String {
  let formatted_amount = decimal(number, precision, language)
  let currency_symbol = currency_symbol(currency_code)
  let currency_position = currency_position(language)

  case currency_position {
    Before -> currency_symbol <> formatted_amount
    After -> {
      let space = case language {
        "es" -> ""
        // Spanish: 24€ (no space)
        "fr" | "de" | "it" -> " "
        // French/German/Italian: 24 € (with space)
        _ -> " "
        // Default with space
      }
      formatted_amount <> space <> currency_symbol
    }
  }
}

fn percentage(number: Float, precision: Int, language: String) -> String {
  let percentage_value = number *. 100.0
  let formatted = decimal(percentage_value, precision, language)
  let percent_symbol = percent_symbol()

  case language {
    "fr" -> formatted <> " " <> percent_symbol
    _ -> formatted <> percent_symbol
  }
}

fn scientific(number: Float, precision: Int) -> String {
  let exponent = case number {
    0.0 -> 0
    n -> {
      let abs_n = case n >=. 0.0 {
        True -> n
        False -> float.negate(n)
      }
      let assert Ok(logarithm) = maths.logarithm_10(abs_n)
      float.floor(logarithm)
      |> float.round
    }
  }

  let assert Ok(power) = float.power(10.0, int.to_float(exponent))
  let mantissa = number /. power
  let assert Ok(power) = float.power(10.0, int.to_float(precision))
  let rounded_mantissa = int.to_float(float.round(mantissa *. power)) /. power

  float.to_string(rounded_mantissa) <> "e" <> int.to_string(exponent)
}

fn compact(number: Float, language: String) -> String {
  case number {
    n if n >=. 1_000_000_000.0 -> {
      let billions = n /. 1_000_000_000.0
      float.to_precision(billions, 1) |> float.to_string
      <> billion_suffix(language)
    }
    n if n >=. 1_000_000.0 -> {
      let millions = n /. 1_000_000.0
      float.to_precision(millions, 1) |> float.to_string
      <> million_suffix(language)
    }
    n if n >=. 1000.0 -> {
      let thousands = n /. 1000.0
      float.to_precision(thousands, 1) |> float.to_string
      <> thousand_suffix(language)
    }
    _ -> int.to_string(float.round(number))
  }
}

// Locale-specific formatting helpers
fn decimal_separator(language: String) -> String {
  case language {
    "pt" | "es" | "fr" | "de" -> ","
    _ -> "."
  }
}

fn thousands_separator(language: String) -> String {
  case language {
    "fr" | "es" | "pt" | "it" -> " "
    // Non-breaking space
    "de" | "at" | "ch" -> "."
    "in" -> ","
    _ -> ","
    // Default for en, etc.
  }
}

fn currency_symbol(currency_code: String) -> String {
  case currency_code {
    "USD" -> "$"
    "EUR" -> "€"
    "GBP" -> "£"
    "BRL" -> "R$"
    "JPY" -> "¥"
    _ -> currency_code
  }
}

type CurrencyPosition {
  Before
  After
}

fn currency_position(language: String) -> CurrencyPosition {
  case language {
    "en" -> Before
    "pt" -> Before
    "es" -> After
    "fr" -> After
    "de" -> After
    "it" -> After
    _ -> Before
  }
}

fn percent_symbol() -> String {
  "%"
}

fn thousand_suffix(language: String) -> String {
  case language {
    "pt" -> "mil"
    "es" -> "k"
    "fr" -> "k"
    _ -> "K"
  }
}

fn million_suffix(language: String) -> String {
  case language {
    "pt" -> "M"
    "es" -> "M"
    "fr" -> "M"
    _ -> "M"
  }
}

fn billion_suffix(language: String) -> String {
  case language {
    "pt" -> "B"
    "es" -> "B"
    "fr" -> "Md"
    _ -> "B"
  }
}

fn add_thousands_separators(
  number_str: String,
  decimal_separator: String,
  thousands_separator: String,
) -> String {
  case string.split(number_str, ".") {
    [integer_part] -> integer_with_separators(integer_part, thousands_separator)
    [integer_part, decimal_part] ->
      integer_with_separators(integer_part, thousands_separator)
      <> decimal_separator
      <> decimal_part
    _ -> number_str
  }
}

fn integer_with_separators(integer_str: String, separator: String) -> String {
  let chars = string.to_graphemes(integer_str) |> list.reverse
  let grouped = group_by_threes_simple(chars)
  grouped
  |> list.map(list.reverse)
  // Reverse each group to get correct order
  |> list.map(string.concat)
  |> list.reverse
  // Groups are built right-to-left, so reverse to get left-to-right
  |> string.join(separator)
}

// Simple approach: group from right to left, return groups in the order they were created
fn group_by_threes_simple(chars: List(String)) -> List(List(String)) {
  case chars {
    [] -> []
    [a] -> [[a]]
    [a, b] -> [[a, b]]
    [a, b, c, ..rest] -> [[a, b, c], ..group_by_threes_simple(rest)]
  }
}

// Date formatting implementations
fn date_short(date: calendar.Date, language: String) -> String {
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

fn date_medium(date: calendar.Date, language: String) -> String {
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

fn date_long(date: calendar.Date, language: String) -> String {
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

fn date_full(date: calendar.Date, language: String) -> String {
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

fn date_custom(date: calendar.Date, pattern: String) -> String {
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

fn time_short(time: calendar.TimeOfDay, language: String) -> String {
  case language {
    "en" -> format_12_hour(time)
    _ -> format_24_hour(time)
  }
}

fn time_medium(time: calendar.TimeOfDay, language: String) -> String {
  case language {
    "en" -> format_12_hour_with_seconds(time)
    _ -> format_24_hour_with_seconds(time)
  }
}

fn time_long(time: calendar.TimeOfDay, language: String) -> String {
  time_medium(time, language) <> " GMT"
}

fn time_full(time: calendar.TimeOfDay, language: String) -> String {
  time_long(time, language)
}

fn time_custom(time: calendar.TimeOfDay, pattern: String) -> String {
  pattern
  |> string.replace("HH", pad_zero(time.hours))
  |> string.replace("mm", pad_zero(time.minutes))
  |> string.replace("ss", pad_zero(time.seconds))
}

fn datetime_short(
  date: calendar.Date,
  time: calendar.TimeOfDay,
  language: String,
) -> String {
  let date_part = date_short(date, language)
  let time_part = time_short(time, language)
  date_part <> " " <> time_part
}

fn datetime_medium(
  date: calendar.Date,
  time: calendar.TimeOfDay,
  language: String,
) -> String {
  let date_part = date_medium(date, language)
  let time_part = time_medium(time, language)
  date_part <> " " <> time_part
}

fn datetime_long(
  date: calendar.Date,
  time: calendar.TimeOfDay,
  language: String,
) -> String {
  let date_part = date_long(date, language)
  let time_part = time_long(time, language)
  date_part <> " " <> time_part
}

fn datetime_full(
  date: calendar.Date,
  time: calendar.TimeOfDay,
  language: String,
) -> String {
  datetime_long(date, time, language)
}

fn datetime_custom(
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
  int.to_string(hour_12) <> ":" <> pad_zero(time.minutes) <> " " <> ampm
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
  int.to_string(hour_12)
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

/// Create a new empty parameter container for string formatting.
///
/// ## Examples
/// ```gleam
/// let params = g18n.new()
///   |> g18n.add_param("name", "Alice")
///   |> g18n.add_param("count", "5")
/// ```
pub fn new_format_params() -> FormatParams {
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
fn format_string(template: String, params: FormatParams) -> String {
  dict.fold(params, template, fn(acc, key, value) {
    string.replace(acc, "{" <> key <> "}", value)
  })
}

fn has_prefix(key_parts: List(String), prefix_parts: List(String)) -> Bool {
  case prefix_parts, key_parts {
    [], _ -> True
    [prefix_head, ..prefix_tail], [key_head, ..key_tail]
      if prefix_head == key_head
    -> has_prefix(key_tail, prefix_tail)
    _, _ -> False
  }
}

@internal
pub fn extract_trie(translations: Translations) -> trie.Trie(String, String) {
  translations.translations
}
