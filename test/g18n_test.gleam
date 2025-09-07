import g18n
import g18n/locale
import gleam/list

// import gleam/option.{Some}
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
