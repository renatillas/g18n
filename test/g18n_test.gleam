import g18n
import g18n/locale
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleam/time/calendar
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn locale_creation_test() {
  let assert Ok(locale_en) = locale.new("en")
  let assert Ok(locale_en_us) = locale.new("en-US")
  let assert Ok(locale_pt_br) = locale.new("pt-BR")

  assert locale.to_string(locale_en) == "en"
  assert locale.to_string(locale_en_us) == "en-US"
  assert locale.to_string(locale_pt_br) == "pt-BR"
}

pub fn invalid_locale_test() {
  let assert Error(_) = locale.new("invalid")
  let assert Error(_) = locale.new("en-INVALID")
  let assert Error(_) = locale.new("")
}

pub fn basic_translation_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("hello", "Hello")
    |> g18n.add_translation("goodbye", "Goodbye")
    |> g18n.add_translation("ui.button.save", "Save")
    |> g18n.add_translation("ui.button.cancel", "Cancel")

  let translator = g18n.new_translator(en_locale, translations)

  assert g18n.translate(translator, "hello") == "Hello"
  assert g18n.translate(translator, "goodbye") == "Goodbye"
  assert g18n.translate(translator, "ui.button.save") == "Save"
  assert g18n.translate(translator, "ui.button.cancel") == "Cancel"
  assert g18n.translate(translator, "missing.key") == "missing.key"
}

pub fn translation_with_parameters_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("welcome", "Welcome {name}!")
    |> g18n.add_translation("user_count", "You have {count} users")

  let translator = g18n.new_translator(en_locale, translations)
  let params =
    g18n.new_format_params()
    |> g18n.add_param("name", "Alice")
    |> g18n.add_param("count", "5")

  assert g18n.translate_with_params(translator, "welcome", params)
    == "Welcome Alice!"
  assert g18n.translate_with_params(translator, "user_count", params)
    == "You have 5 users"
}

pub fn pluralization_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("item.one", "1 item")
    |> g18n.add_translation("item.other", "{count} items")

  let translator = g18n.new_translator(en_locale, translations)

  assert g18n.translate_plural(translator, "item", 1) == "1 item"
  assert g18n.translate_plural(translator, "item", 5) == "5 items"
  assert g18n.translate_plural(translator, "item", 0) == "0 items"
}

pub fn ordinal_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("place.first", "{ordinal} place")
    |> g18n.add_translation("place.second", "{ordinal} place")
    |> g18n.add_translation("place.third", "{ordinal} place")
    |> g18n.add_translation("place.nth", "{ordinal} place")

  let translator = g18n.new_translator(en_locale, translations)
  let params = g18n.new_format_params()

  assert g18n.translate_ordinal_with_params(translator, "place", 1, params)
    == "1st place"
  assert g18n.translate_ordinal_with_params(translator, "place", 2, params)
    == "2nd place"
  assert g18n.translate_ordinal_with_params(translator, "place", 3, params)
    == "3rd place"
  assert g18n.translate_ordinal_with_params(translator, "place", 4, params)
    == "4th place"
  assert g18n.translate_ordinal_with_params(translator, "place", 11, params)
    == "11th place"
  assert g18n.translate_ordinal_with_params(translator, "place", 21, params)
    == "21st place"
}

pub fn context_sensitive_translation_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations =
    g18n.new_translations()
    |> g18n.add_context_translation(
      "bank",
      "financial",
      "financial institution",
    )
    |> g18n.add_context_translation("bank", "river", "riverbank")
    |> g18n.add_translation("bank", "bank")

  let translator = g18n.new_translator(en_locale, translations)

  assert g18n.translate_with_context(
      translator,
      "bank",
      g18n.Context("financial"),
    )
    == "financial institution"
  assert g18n.translate_with_context(translator, "bank", g18n.Context("river"))
    == "riverbank"
  assert g18n.translate_with_context(translator, "bank", g18n.NoContext)
    == "bank"
  assert g18n.translate_with_context(
      translator,
      "bank",
      g18n.Context("unknown"),
    )
    == "bank@unknown"
}

pub fn fallback_translation_test() {
  let assert Ok(en_locale) = locale.new("en")
  let assert Ok(es_locale) = locale.new("es")

  let en_translations =
    g18n.new_translations()
    |> g18n.add_translation("hello", "Hello")
    |> g18n.add_translation("goodbye", "Goodbye")

  let es_translations =
    g18n.new_translations()
    |> g18n.add_translation("hello", "Hola")
  // Missing "goodbye" translation

  let translator =
    g18n.new_translator(es_locale, es_translations)
    |> g18n.with_fallback(en_locale, en_translations)

  assert g18n.translate(translator, "hello") == "Hola"
  assert g18n.translate(translator, "goodbye") == "Goodbye"
  // Falls back to English
}

pub fn json_import_flat_test() {
  let json_string =
    "{\"hello\": \"Hello\", \"user.name\": \"Name\", \"ui.button.save\": \"Save\"}"
  let assert Ok(translations) = g18n.translations_from_json(json_string)
  let assert Ok(en_locale) = locale.new("en")
  let translator = g18n.new_translator(en_locale, translations)

  assert g18n.translate(translator, "hello") == "Hello"
  assert g18n.translate(translator, "user.name") == "Name"
  assert g18n.translate(translator, "ui.button.save") == "Save"
}

pub fn json_import_nested_test() {
  let nested_json =
    "{\"ui\": {\"button\": {\"save\": \"Save\", \"cancel\": \"Cancel\"}}, \"user\": {\"name\": \"Name\"}}"
  let assert Ok(translations) = g18n.translations_from_nested_json(nested_json)
  let assert Ok(en_locale) = locale.new("en")
  let translator = g18n.new_translator(en_locale, translations)

  assert g18n.translate(translator, "ui.button.save") == "Save"
  assert g18n.translate(translator, "ui.button.cancel") == "Cancel"
  assert g18n.translate(translator, "user.name") == "Name"
}

pub fn json_export_test() {
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("hello", "Hello")
    |> g18n.add_translation("user.name", "Name")

  let json_output = g18n.translations_to_json(translations)
  let assert Ok(reimported) = g18n.translations_from_json(json_output)

  let assert Ok(en_locale) = locale.new("en")
  let translator = g18n.new_translator(en_locale, reimported)

  assert g18n.translate(translator, "hello") == "Hello"
  assert g18n.translate(translator, "user.name") == "Name"
}

pub fn validation_test() {
  let assert Ok(es_locale) = locale.new("es")

  let primary_translations =
    g18n.new_translations()
    |> g18n.add_translation("welcome", "Welcome {name}!")
    |> g18n.add_translation("item.one", "1 item")
    |> g18n.add_translation("item.other", "{count} items")

  let target_translations =
    g18n.new_translations()
    |> g18n.add_translation("welcome", "¡Bienvenido {name}!")
    |> g18n.add_translation("item.one", "1 artículo")
  // Missing item.other translation

  let report =
    g18n.validate_translations(
      primary_translations,
      target_translations,
      es_locale,
    )

  assert report.total_keys == 3
  assert report.translated_keys == 2
  assert list.length(report.errors) > 0
  // Should have missing translation error
}

pub fn number_formatting_test() {
  let assert Ok(en_locale) = locale.new("en")
  let assert Ok(es_locale) = locale.new("es")
  let translations = g18n.new_translations()

  let en_translator = g18n.new_translator(en_locale, translations)
  let es_translator = g18n.new_translator(es_locale, translations)

  // Test basic number formatting
  let en_formatted = g18n.format_number(en_translator, 1234.56, g18n.Decimal(2))
  let es_formatted = g18n.format_number(es_translator, 1234.56, g18n.Decimal(2))

  // Both should format the number (exact format may vary)
  assert string.contains(en_formatted, "1,234")
  assert string.contains(es_formatted, "1 234")
}

pub fn currency_formatting_test() {
  let assert Ok(us_locale) = locale.new("en-US")
  let translations = g18n.new_translations()
  let translator = g18n.new_translator(us_locale, translations)

  let formatted =
    g18n.format_number(translator, 1234.56, g18n.Currency("USD", 2))
  assert string.contains(formatted, "1,234")
  assert string.contains(formatted, "56")
}

pub fn currency_position_locale_test() {
  let assert Ok(es_locale) = locale.new("es")
  let assert Ok(fr_locale) = locale.new("fr")
  let assert Ok(de_locale) = locale.new("de")
  let assert Ok(en_locale) = locale.new("en")
  let translations = g18n.new_translations()

  let es_translator = g18n.new_translator(es_locale, translations)
  let fr_translator = g18n.new_translator(fr_locale, translations)
  let de_translator = g18n.new_translator(de_locale, translations)
  let en_translator = g18n.new_translator(en_locale, translations)

  // Test Spanish: 24€ (no space, currency after, 0 precision = no decimals)
  let spanish = g18n.format_number(es_translator, 24.0, g18n.Currency("EUR", 0))
  assert spanish == "24€"

  // Test French: 24 € (space, currency after, 0 precision = no decimals)
  let french = g18n.format_number(fr_translator, 24.0, g18n.Currency("EUR", 0))
  assert french == "24 €"

  // Test German: 24 € (space, currency after, 0 precision = no decimals)  
  let german = g18n.format_number(de_translator, 24.0, g18n.Currency("EUR", 0))
  assert german == "24 €"

  // Test English: $24 (currency before, 0 precision = no decimals)
  let english = g18n.format_number(en_translator, 24.0, g18n.Currency("USD", 0))
  assert english == "$24"
}

pub fn number_precision_test() {
  let assert Ok(en_locale) = locale.new("en")
  let assert Ok(es_locale) = locale.new("es")
  let translations = g18n.new_translations()
  let en_translator = g18n.new_translator(en_locale, translations)
  let es_translator = g18n.new_translator(es_locale, translations)

  // Test 0 precision - should show no decimals
  assert g18n.format_number(en_translator, 24.0, g18n.Decimal(0)) == "24"
  assert g18n.format_number(es_translator, 24.0, g18n.Decimal(0)) == "24"

  // Test 2 precision - should show exactly 2 decimals  
  assert g18n.format_number(en_translator, 24.0, g18n.Decimal(2)) == "24.00"
  assert g18n.format_number(es_translator, 24.0, g18n.Decimal(2)) == "24,00"

  // Test with currency and 0 precision
  assert g18n.format_number(en_translator, 24.56, g18n.Currency("USD", 0))
    == "$25"
  // Rounded
  assert g18n.format_number(es_translator, 24.56, g18n.Currency("EUR", 0))
    == "25€"
  // Rounded

  // Test with various precision values  
  assert g18n.format_number(en_translator, 123.4, g18n.Decimal(3)) == "123.400"
  assert g18n.format_number(es_translator, 123.456789, g18n.Decimal(2))
    == "123,46"
  // Rounded
}

pub fn date_formatting_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations = g18n.new_translations()
  let translator = g18n.new_translator(en_locale, translations)
  let date = calendar.Date(2024, calendar.January, 15)

  let formatted = g18n.format_date(translator, date, g18n.Full)
  // Should include year and month name
  assert string.contains(formatted, "2024")
  assert string.contains(formatted, "January")
}

pub fn relative_time_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations = g18n.new_translations()
  let translator = g18n.new_translator(en_locale, translations)

  let past_time =
    g18n.format_relative_time(translator, g18n.Hours(2), g18n.Past)
  let future_time =
    g18n.format_relative_time(translator, g18n.Hours(2), g18n.Future)

  assert past_time == "2 hours ago"
  assert future_time == "in 2 hours"
}

pub fn css_direction_test() {
  let assert Ok(en_locale) = locale.new("en")
  let assert Ok(ar_locale) = locale.new("ar")

  assert locale.get_css_direction(en_locale) == "ltr"
  assert locale.get_css_direction(ar_locale) == "rtl"
}

pub fn context_variants_test() {
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("bank", "bank")
    |> g18n.add_context_translation(
      "bank",
      "financial",
      "financial institution",
    )
    |> g18n.add_context_translation("bank", "river", "riverbank")

  let variants = g18n.context_variants(translations, "bank")
  assert list.length(variants) == 3
}

pub fn get_keys_with_prefix_test() {
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("ui.button.save", "Save")
    |> g18n.add_translation("ui.button.cancel", "Cancel")
    |> g18n.add_translation("ui.dialog.confirm", "Confirm")
    |> g18n.add_translation("user.name", "Name")

  let button_keys = g18n.get_keys_with_prefix(translations, "ui.button")
  assert list.length(button_keys) == 2

  let ui_keys = g18n.get_keys_with_prefix(translations, "ui")
  assert list.length(ui_keys) == 3
}

pub fn extract_placeholders_test() {
  let placeholders1 = g18n.extract_placeholders("Welcome {name}!")
  assert placeholders1 == ["name"]

  let placeholders2 = g18n.extract_placeholders("Hello {firstName} {lastName}")
  assert placeholders2 == ["firstName", "lastName"]

  let placeholders3 = g18n.extract_placeholders("No placeholders here")
  assert placeholders3 == []
}

pub fn validate_translation_parameters_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("welcome", "Welcome {name}!")
    |> g18n.add_translation("user_info", "User: {name}, Age: {age}")

  let errors1 =
    g18n.validate_translation_parameters(
      translations,
      "welcome",
      ["name"],
      en_locale,
    )
  assert errors1 == []

  let errors2 =
    g18n.validate_translation_parameters(
      translations,
      "user_info",
      ["name"],
      en_locale,
    )
  assert list.length(errors2) > 0
  // Missing "age" parameter
}

pub fn translation_coverage_test() {
  let primary =
    g18n.new_translations()
    |> g18n.add_translation("hello", "Hello")
    |> g18n.add_translation("goodbye", "Goodbye")
    |> g18n.add_translation("welcome", "Welcome")

  let target =
    g18n.new_translations()
    |> g18n.add_translation("hello", "Hola")
    |> g18n.add_translation("goodbye", "Adiós")
  // Missing "welcome"

  let coverage_pct = g18n.translation_coverage(primary, target)
  assert coverage_pct >=. 0.0 && coverage_pct <=. 1.0
  // Should be a percentage between 0 and 1
}

pub fn find_unused_translations_test() {
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("hello", "Hello")
    |> g18n.add_translation("goodbye", "Goodbye")
    |> g18n.add_translation("unused_key", "Unused")

  let used_keys = ["hello", "goodbye"]
  // "unused_key" is not used
  let unused = g18n.find_unused_translations(translations, used_keys)
  assert list.length(unused) == 1
}

pub fn export_validation_report_test() {
  let assert Ok(es_locale) = locale.new("es")
  let primary =
    g18n.new_translations()
    |> g18n.add_translation("hello", "Hello")
    |> g18n.add_translation("goodbye", "Goodbye")

  let target =
    g18n.new_translations()
    |> g18n.add_translation("hello", "Hola")
  // Missing "goodbye"

  let report = g18n.validate_translations(primary, target, es_locale)
  let exported = g18n.export_validation_report(report)

  assert string.contains(exported, "Translation Validation Report")
  assert string.contains(exported, "es")
}

pub fn translations_to_nested_json_test() {
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("ui.button.save", "Save")
    |> g18n.add_translation("ui.button.cancel", "Cancel")
    |> g18n.add_translation(
      "very.nested.json.structure.that.will.fail.sometimes",
      "Nested",
    )
    |> g18n.add_translation("user.name", "Name")

  let nested_json = g18n.translations_to_nested_json(translations)

  // Debug: print what we got
  // io.println("Nested JSON: " <> nested_json)

  let assert Ok(reimported) = g18n.translations_from_nested_json(nested_json)
  let assert Ok(en_locale) = locale.new("en")
  let translator = g18n.new_translator(en_locale, reimported)

  // Test that roundtrip conversion works
  assert g18n.translate(translator, "ui.button.save") == "Save"
  assert g18n.translate(translator, "ui.button.cancel") == "Cancel"
  assert g18n.translate(translator, "user.name") == "Name"
  assert g18n.translate(
      translator,
      "very.nested.json.structure.that.will.fail.sometimes",
    )
    == "Nested"
}

pub fn translate_with_context_and_params_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations =
    g18n.new_translations()
    |> g18n.add_context_translation("open", "file", "Open {filename}")
    |> g18n.add_context_translation("open", "door", "Open the {location} door")

  let translator = g18n.new_translator(en_locale, translations)
  let params = g18n.new_format_params() |> g18n.add_param("filename", "doc.pdf")

  let result =
    g18n.translate_with_context_and_params(
      translator,
      "open",
      g18n.Context("file"),
      params,
    )
  assert result == "Open doc.pdf"
}

pub fn translate_plural_with_params_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("item.one", "1 {type}")
    |> g18n.add_translation("item.other", "{count} {type}s")

  let translator = g18n.new_translator(en_locale, translations)
  let params = g18n.new_format_params() |> g18n.add_param("type", "book")

  assert g18n.translate_plural_with_params(translator, "item", 1, params)
    == "1 book"
  assert g18n.translate_plural_with_params(translator, "item", 5, params)
    == "5 books"
}

pub fn translate_cardinal_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("item.one", "1 item")
    |> g18n.add_translation("item.other", "{count} items")

  let translator = g18n.new_translator(en_locale, translations)

  assert g18n.translate_cardinal(translator, "item", 1) == "1 item"
  assert g18n.translate_cardinal(translator, "item", 5) == "5 items"
}

pub fn translate_ordinal_basic_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("place.first", "1st place")
    |> g18n.add_translation("place.second", "2nd place")
    |> g18n.add_translation("place.third", "3rd place")
    |> g18n.add_translation("place.nth", "4th place")

  let translator = g18n.new_translator(en_locale, translations)

  assert g18n.translate_ordinal(translator, "place", 1) == "1st place"
  assert g18n.translate_ordinal(translator, "place", 2) == "2nd place"
  assert g18n.translate_ordinal(translator, "place", 4) == "4th place"
}

pub fn translate_range_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("selection.single", "1 item selected")
    |> g18n.add_translation("selection.range", "3-7 items selected")

  let translator = g18n.new_translator(en_locale, translations)

  assert g18n.translate_range(translator, "selection", 1, 1)
    == "1 item selected"
  assert g18n.translate_range(translator, "selection", 3, 7)
    == "3-7 items selected"
}

pub fn translate_range_with_params_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("selection.single", "1 {type} selected")
    |> g18n.add_translation("selection.range", "{from}-{to} {type}s selected")

  let translator = g18n.new_translator(en_locale, translations)
  let params = g18n.new_format_params() |> g18n.add_param("type", "file")

  assert g18n.translate_range_with_params(translator, "selection", 1, 1, params)
    == "1 file selected"
  assert g18n.translate_range_with_params(translator, "selection", 3, 5, params)
    == "3-5 files selected"
}

pub fn translator_getter_functions_test() {
  let assert Ok(en_locale) = locale.new("en")
  let assert Ok(es_locale) = locale.new("es")
  let en_translations =
    g18n.new_translations() |> g18n.add_translation("hello", "Hello")
  let es_translations =
    g18n.new_translations() |> g18n.add_translation("hola", "Hola")

  let translator =
    g18n.new_translator(en_locale, en_translations)
    |> g18n.with_fallback(es_locale, es_translations)

  assert locale.to_string(g18n.locale(translator)) == "en"

  let assert Some(fallback) = g18n.fallback_locale(translator)
  assert locale.to_string(fallback) == "es"

  let primary_trans = g18n.translations(translator)
  assert g18n.translate(g18n.new_translator(en_locale, primary_trans), "hello")
    == "Hello"

  let assert Some(_) = g18n.fallback_translations(translator)
}

pub fn namespace_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("ui.button.save", "Save")
    |> g18n.add_translation("ui.button.cancel", "Cancel")
    |> g18n.add_translation("ui.dialog.confirm", "Confirm")
    |> g18n.add_translation("user.name", "Name")

  let translator = g18n.new_translator(en_locale, translations)
  let ui_namespace = g18n.namespace(translator, "ui")

  assert list.length(ui_namespace) == 3
  // Should contain 3 UI-related keys

  // Check if the ui.button.save key-value pair is in the namespace
  assert list.any(ui_namespace, fn(kv) {
    let #(key, value) = kv
    key == "ui.button.save" && value == "Save"
  })
}

pub fn format_time_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations = g18n.new_translations()
  let translator = g18n.new_translator(en_locale, translations)

  let time = calendar.TimeOfDay(14, 30, 45, 0)
  let formatted = g18n.format_time(translator, time, g18n.Short)

  assert string.contains(formatted, "14") || string.contains(formatted, "2")
  assert string.contains(formatted, "30")
}

pub fn format_datetime_test() {
  let assert Ok(en_locale) = locale.new("en")
  let translations = g18n.new_translations()
  let translator = g18n.new_translator(en_locale, translations)

  let date = calendar.Date(2024, calendar.January, 15)
  let time = calendar.TimeOfDay(14, 30, 45, 0)

  let formatted = g18n.format_datetime(translator, date, time, g18n.Short)

  // Short format shows "01/15/24" not "2024", so check for "24" and "15"
  assert string.contains(formatted, "24") || string.contains(formatted, "2024")
  assert string.contains(formatted, "15")
  assert string.contains(formatted, "30")
}

// Locale module tests
pub fn locale_language_region_test() {
  let assert Ok(en_us) = locale.new("en-US")
  let assert Ok(pt) = locale.new("pt")

  assert locale.language(en_us) == "en"
  assert locale.language(pt) == "pt"

  let assert Some("US") = locale.region(en_us)

  let assert None = locale.region(pt)
}

pub fn locale_matching_test() {
  let assert Ok(en_us) = locale.new("en-US")
  let assert Ok(en_gb) = locale.new("en-GB")
  let assert Ok(es) = locale.new("es")
  let assert Ok(en_us2) = locale.new("en-US")

  assert locale.match_language(en_us, en_gb)
  assert !locale.match_language(en_us, es)

  assert locale.exact_match(en_us, en_us2)
  assert !locale.exact_match(en_us, en_gb)

  let en_only = locale.language_only(en_us)
  assert locale.to_string(en_only) == "en"
}

pub fn locale_negotiation_test() {
  let assert Ok(en) = locale.new("en")
  let assert Ok(en_us) = locale.new("en-US")
  let assert Ok(es) = locale.new("es")
  let assert Ok(fr) = locale.new("fr")
  let assert Ok(en_gb) = locale.new("en-GB")

  let available = [en, en_us, es]
  let preferred_with_gb = [en_gb, fr]
  // en-GB not available, should match en or en_us

  let assert Ok(matched) = locale.negotiate_locale(available, preferred_with_gb)
  assert locale.language(matched) == "en"
}

pub fn parse_accept_language_test() {
  let parsed = locale.parse_accept_language("en-US,en;q=0.9,fr;q=0.8,es;q=0.7")
  assert list.length(parsed) >= 3

  let assert Ok(first) = list.first(parsed)
  assert locale.language(first) == "en"
}

pub fn locale_quality_score_test() {
  let assert Ok(en_us) = locale.new("en-US")
  let assert Ok(en_gb) = locale.new("en-GB")
  let assert Ok(es) = locale.new("es")

  let exact_score = locale.locale_quality_score(en_us, en_us)
  assert exact_score == 1.0

  let lang_score = locale.locale_quality_score(en_us, en_gb)
  assert lang_score == 0.8

  let no_match_score = locale.locale_quality_score(en_us, es)
  assert no_match_score == 0.0
}
