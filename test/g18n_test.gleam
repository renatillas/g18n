import g18n
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/time/calendar
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn locale_creation_test() {
  let assert Ok(locale_en) = g18n.locale("en")
  let assert Ok(locale_en_us) = g18n.locale("en-US")
  let assert Ok(locale_pt_br) = g18n.locale("pt-BR")

  assert g18n.locale_string(locale_en) == "en"
  assert g18n.locale_string(locale_en_us) == "en-US"
  assert g18n.locale_string(locale_pt_br) == "pt-BR"
}

pub fn invalid_locale_test() {
  let assert Error(_) = g18n.locale("invalid")
  let assert Error(_) = g18n.locale("en-INVALID")
  let assert Error(_) = g18n.locale("")
}

pub fn trie_basic_translation_test() {
  let assert Ok(locale) = g18n.locale("en")
  let translations =
    g18n.translations()
    |> g18n.add_translation("hello", "Hello")
    |> g18n.add_translation("goodbye", "Goodbye")
    |> g18n.add_translation("ui.button.save", "Save")
    |> g18n.add_translation("ui.button.cancel", "Cancel")

  let translator = g18n.translator(locale, translations)

  assert g18n.translate(translator, "hello") == "Hello"
  assert g18n.translate(translator, "goodbye") == "Goodbye"
  assert g18n.translate(translator, "ui.button.save") == "Save"
  assert g18n.translate(translator, "ui.button.cancel") == "Cancel"
  assert g18n.translate(translator, "missing.key") == "missing.key"
}

pub fn trie_hierarchical_keys_test() {
  let assert Ok(locale) = g18n.locale("en")
  let translations =
    g18n.translations()
    |> g18n.add_translation("ui.button.save", "Save")
    |> g18n.add_translation("ui.button.cancel", "Cancel")
    |> g18n.add_translation("ui.menu.file", "File")
    |> g18n.add_translation("ui.menu.edit", "Edit")
    |> g18n.add_translation(
      "errors.validation.required",
      "This field is required",
    )
    |> g18n.add_translation("errors.validation.email", "Invalid email format")

  let translator = g18n.translator(locale, translations)

  assert "Save" == g18n.translate(translator, "ui.button.save")
  assert "File" == g18n.translate(translator, "ui.menu.file")
  assert "This field is required"
    == g18n.translate(translator, "errors.validation.required")

  assert "missing.key" == g18n.translate(translator, "missing.key")
}

pub fn trie_namespace_functionality_test() {
  let assert Ok(locale) = g18n.locale("en")
  let translations =
    g18n.translations()
    |> g18n.add_translation("ui.button.save", "Save")
    |> g18n.add_translation("ui.button.cancel", "Cancel")
    |> g18n.add_translation("ui.button.delete", "Delete")
    |> g18n.add_translation("ui.menu.file", "File")
    |> g18n.add_translation("errors.validation.required", "Required")
    |> g18n.add_translation("errors.network.timeout", "Timeout")

  let translator = g18n.translator(locale, translations)

  // Get all UI button translations
  assert [
      #("ui.button.cancel", "Cancel"),
      #("ui.button.delete", "Delete"),
      #("ui.button.save", "Save"),
    ]
    == g18n.get_namespace(translator, "ui.button")

  // Get all error translations  
  assert [
      #("errors.network.timeout", "Timeout"),
      #("errors.validation.required", "Required"),
    ]
    == g18n.get_namespace(translator, "errors")

  // Get specific namespace keys
  assert ["ui.button.cancel", "ui.button.delete", "ui.button.save"]
    == g18n.get_keys_with_prefix(translations, "ui.button")
}

pub fn trie_with_parameters_test() {
  let assert Ok(locale) = g18n.locale("en")
  let translations =
    g18n.translations()
    |> g18n.add_translation("user.welcome", "Welcome {name}!")
    |> g18n.add_translation(
      "user.profile.messages",
      "You have {count} new messages",
    )
    |> g18n.add_translation(
      "notifications.email.subject",
      "Hello {name}, you have {count} notifications",
    )

  let translator = g18n.translator(locale, translations)
  let params =
    g18n.format_params()
    |> g18n.add_param("name", "Alice")
    |> g18n.add_param("count", "5")

  assert "Welcome Alice!"
    == g18n.translate_with_params(translator, "user.welcome", params)
  assert "You have 5 new messages"
    == g18n.translate_with_params(translator, "user.profile.messages", params)
  assert "Hello Alice, you have 5 notifications"
    == g18n.translate_with_params(
      translator,
      "notifications.email.subject",
      params,
    )
}

pub fn trie_fallback_test() {
  let assert Ok(en_locale) = g18n.locale("en")
  let assert Ok(en_us_locale) = g18n.locale("en-US")

  let en_translations =
    g18n.translations()
    |> g18n.add_translation("common.hello", "Hello")
    |> g18n.add_translation("common.goodbye", "Goodbye")
    |> g18n.add_translation("ui.button.save", "Save")

  let en_us_translations =
    g18n.translations()
    |> g18n.add_translation("common.hello", "Hey there!")
    |> g18n.add_translation("ui.button.cancel", "Cancel")

  let translator =
    g18n.translator(en_us_locale, en_us_translations)
    |> g18n.with_fallback(en_locale, en_translations)

  assert "Hey there!" == g18n.translate(translator, "common.hello")
  assert "Goodbye" == g18n.translate(translator, "common.goodbye")
  assert "Save" == g18n.translate(translator, "ui.button.save")
  assert "Cancel" == g18n.translate(translator, "ui.button.cancel")
  assert "missing.key" == g18n.translate(translator, "missing.key")
}

pub fn pluralization_test() {
  let assert Ok(locale) = g18n.locale("en")
  let translations =
    g18n.translations()
    |> g18n.add_translation("item.one", "1 item")
    |> g18n.add_translation("item.other", "{count} items")

  let translator = g18n.translator(locale, translations)

  assert g18n.translate_plural(translator, "item", 1) == "1 item"
  assert g18n.translate_plural(translator, "item", 5) == "{count} items"

  let params = g18n.format_params() |> g18n.add_param("count", "5")
  assert "5 items"
    == g18n.translate_plural_with_params(translator, "item", 5, params)
}

pub fn json_integration_test() {
  let assert Ok(locale) = g18n.locale("en")
  let generated_translations =
    g18n.translations_from_json(
      json.object([
        #("hello", json.string("Hello")),
        #("ui.button.save", json.string("Save")),
        #("user.welcome", json.string("Welcome {name}!")),
        #("item.one", json.string("1 item")),
        #("item.other", json.string("{count} items")),
      ])
      |> json.to_string,
    )

  let assert Ok(translations) = generated_translations
  let translator = g18n.translator(locale, translations)

  assert "Hello" == g18n.translate(translator, "hello")
  assert "Save" == g18n.translate(translator, "ui.button.save")
  let params = g18n.format_params() |> g18n.add_param("name", "Alice")
  assert "Welcome Alice!"
    == g18n.translate_with_params(translator, "user.welcome", params)

  assert "1 item" == g18n.translate_plural(translator, "item", 1)
  assert "{count} items" == g18n.translate_plural(translator, "item", 5)
}

pub fn advanced_pluralization_test() {
  let assert Ok(locale) = g18n.locale("en")
  let translations =
    g18n.translations()
    |> g18n.add_translation("position.first", "{ordinal} place")
    |> g18n.add_translation("position.second", "{ordinal} place")
    |> g18n.add_translation("position.third", "{ordinal} place")
    |> g18n.add_translation("position.nth", "{ordinal} place")
    |> g18n.add_translation("selection.single", "{from} item selected")
    |> g18n.add_translation(
      "selection.range",
      "{from}-{to} items selected ({total} total)",
    )

  let translator = g18n.translator(locale, translations)

  // Test ordinals (should return templates before parameter substitution)
  assert "{ordinal} place" == g18n.translate_ordinal(translator, "position", 1)
  assert "{ordinal} place" == g18n.translate_ordinal(translator, "position", 2)
  assert "{ordinal} place" == g18n.translate_ordinal(translator, "position", 3)
  assert "{ordinal} place" == g18n.translate_ordinal(translator, "position", 4)

  // Test ordinals with parameters (should substitute the ordinal suffix)
  let params = g18n.format_params()
  assert "1st place"
    == g18n.translate_ordinal_with_params(translator, "position", 1, params)
  assert "4th place"
    == g18n.translate_ordinal_with_params(translator, "position", 4, params)
  assert "21st place"
    == g18n.translate_ordinal_with_params(translator, "position", 21, params)

  // Test ranges
  assert "{from} item selected"
    == g18n.translate_range(translator, "selection", 1, 1)
  assert "{from}-{to} items selected ({total} total)"
    == g18n.translate_range(translator, "selection", 1, 5)

  // Test ranges with parameters
  assert "1 item selected"
    == g18n.translate_range_with_params(translator, "selection", 1, 1, params)
  assert "3-7 items selected (5 total)"
    == g18n.translate_range_with_params(translator, "selection", 3, 7, params)
}

pub fn number_formatting_test() {
  let assert Ok(en_locale) = g18n.locale("en-US")
  let assert Ok(pt_locale) = g18n.locale("pt-BR")

  let translations = g18n.translations()
  let en_translator = g18n.translator(en_locale, translations)
  let pt_translator = g18n.translator(pt_locale, translations)

  // Test decimal formatting
  let assert "1234.56" =
    g18n.format_number(en_translator, 1234.56, g18n.Decimal(2))
  let assert "1234.56" =
    g18n.format_number(pt_translator, 1234.56, g18n.Decimal(2))

  // Test currency formatting
  assert "$29.99"
    == g18n.format_number(en_translator, 29.99, g18n.Currency("USD", 2))
  assert "R$29.99"
    == g18n.format_number(pt_translator, 29.99, g18n.Currency("BRL", 2))

  // Test percentage formatting
  assert "75.0%" == g18n.format_number(en_translator, 0.75, g18n.Percentage(1))
  let assert "75.0%" =
    g18n.format_number(pt_translator, 0.75, g18n.Percentage(1))

  // Test compact formatting
  assert "1.5M" == g18n.format_number(en_translator, 1_500_000.0, g18n.Compact)
  // Basic assertions (simplified since exact formatting depends on implementation)
}

pub fn date_time_formatting_test() {
  let assert Ok(en_locale) = g18n.locale("en")
  let assert Ok(pt_locale) = g18n.locale("pt")

  let translations = g18n.translations()
  let en_translator = g18n.translator(en_locale, translations)
  let pt_translator = g18n.translator(pt_locale, translations)

  let date = calendar.Date(2023, calendar.December, 25)

  assert "12/25/23" == g18n.format_date(en_translator, date, g18n.Short)
  assert "25/12/23" == g18n.format_date(pt_translator, date, g18n.Short)
  assert "Dec 25, 2023" == g18n.format_date(en_translator, date, g18n.Medium)
  assert "25 de dez de 2023"
    == g18n.format_date(pt_translator, date, g18n.Medium)
  assert "December 25, 2023 GMT"
    == g18n.format_date(en_translator, date, g18n.Long)
  assert "25 de dezembro de 2023 GMT"
    == g18n.format_date(pt_translator, date, g18n.Long)
  assert "Monday, December 25, 2023 GMT"
    == g18n.format_date(en_translator, date, g18n.Full)
  assert "segunda-feira, 25 de dezembro de 2023 GMT"
    == g18n.format_date(pt_translator, date, g18n.Full)
  assert "2023-12-25"
    == g18n.format_date(en_translator, date, g18n.Custom("YYYY-MM-DD"))

  let time = calendar.TimeOfDay(14, 30, 45, 0)
  assert "2:30 PM" == g18n.format_time(en_translator, time, g18n.Short)
  assert "14:30" == g18n.format_time(pt_translator, time, g18n.Short)

  // Test relative time
  assert "2 hours ago"
    == g18n.format_relative_time(en_translator, g18n.Hours(2), g18n.Past)
  assert "há 3 dias"
    == g18n.format_relative_time(pt_translator, g18n.Days(3), g18n.Past)
  assert "em 3 dias"
    == g18n.format_relative_time(pt_translator, g18n.Days(3), g18n.Future)
}

pub fn translation_validation_test() {
  let assert Ok(locale) = g18n.locale("en")

  let complete_translations =
    g18n.translations()
    |> g18n.add_translation("hello", "Hello")
    |> g18n.add_translation("welcome", "Welcome {name}!")
    |> g18n.add_translation("item.one", "1 item")
    |> g18n.add_translation("item.other", "{count} items")

  let incomplete_translations =
    g18n.translations()
    |> g18n.add_translation("hello", "Hello")
    |> g18n.add_translation("welcome", "Welcome!")
    // Missing {name} parameter
    |> g18n.add_translation("item.one", "1 item")
  // Missing .other form

  let report =
    g18n.validate_translations(
      complete_translations,
      incomplete_translations,
      locale,
    )

  // Should have validation errors
  assert list.length(report.errors) > 0
  assert report.coverage <. 1.0
  assert report.total_keys > report.translated_keys

  // Test coverage calculation
  let coverage =
    g18n.get_translation_coverage(
      complete_translations,
      incomplete_translations,
    )
  assert coverage <. 1.0

  // Test unused translations detection
  let used_keys = ["hello", "welcome"]
  let unused = g18n.find_unused_translations(complete_translations, used_keys)
  assert list.length(unused) > 0

  // Test validation report export
  assert "Translation Validation Report\n================================\nCoverage: 75.0%\nTotal Keys: 4\nTranslated: 3\nErrors: 2\nWarnings: 0\n\nERRORS:\n  - Missing translation for 'item.other' in en\n  - Missing parameter '{name}' in 'welcome' (en)\n"
    == g18n.export_validation_report(report)
}

pub fn namespace_operations_test() {
  let assert Ok(locale) = g18n.locale("en")
  let translations =
    g18n.translations()
    |> g18n.add_translation("ui.button.save", "Save")
    |> g18n.add_translation("ui.button.cancel", "Cancel")
    |> g18n.add_translation("ui.button.delete", "Delete")
    |> g18n.add_translation("ui.dialog.confirm", "Confirm")
    |> g18n.add_translation("errors.network.timeout", "Network timeout")
    |> g18n.add_translation("errors.validation.required", "Required field")

  let translator = g18n.translator(locale, translations)

  // Test namespace retrieval
  let button_translations = g18n.get_namespace(translator, "ui.button")
  assert list.length(button_translations) == 3

  assert [
      #("ui.button.cancel", "Cancel"),
      #("ui.button.delete", "Delete"),
      #("ui.button.save", "Save"),
      #("ui.dialog.confirm", "Confirm"),
    ]
    == g18n.get_namespace(translator, "ui")

  assert [
      #("errors.network.timeout", "Network timeout"),
      #("errors.validation.required", "Required field"),
    ]
    == g18n.get_namespace(translator, "errors")

  // Test prefix key retrieval
  assert ["ui.button.cancel", "ui.button.delete", "ui.button.save"]
    == g18n.get_keys_with_prefix(translations, "ui.button")

  assert ["errors.network.timeout", "errors.validation.required"]
    == g18n.get_keys_with_prefix(translations, "errors")
}

pub fn multi_language_date_formatting_test() {
  // Test a known date: Monday, January 1, 2024 (New Year's Day)
  let date = calendar.Date(2024, calendar.January, 1)
  let translations = g18n.translations()

  // English
  let assert Ok(en_locale) = g18n.locale("en")
  let en_translator = g18n.translator(en_locale, translations)
  assert "01/01/24" == g18n.format_date(en_translator, date, g18n.Short)
  assert "Jan 1, 2024" == g18n.format_date(en_translator, date, g18n.Medium)
  assert "January 1, 2024 GMT"
    == g18n.format_date(en_translator, date, g18n.Long)

  // Spanish
  let assert Ok(es_locale) = g18n.locale("es")
  let es_translator = g18n.translator(es_locale, translations)
  assert "01/01/24" == g18n.format_date(es_translator, date, g18n.Short)
  assert "1 de ene de 2024"
    == g18n.format_date(es_translator, date, g18n.Medium)
  assert "1 de enero de 2024 GMT"
    == g18n.format_date(es_translator, date, g18n.Long)
  assert "lunes, 1 de enero de 2024 GMT"
    == g18n.format_date(es_translator, date, g18n.Full)

  // French
  let assert Ok(fr_locale) = g18n.locale("fr")
  let fr_translator = g18n.translator(fr_locale, translations)
  assert "01/01/24" == g18n.format_date(fr_translator, date, g18n.Short)
  assert "1 janv 2024" == g18n.format_date(fr_translator, date, g18n.Medium)
  assert "1 janvier 2024 GMT"
    == g18n.format_date(fr_translator, date, g18n.Long)
  assert "lundi 1 janvier 2024 GMT"
    == g18n.format_date(fr_translator, date, g18n.Full)

  // German
  let assert Ok(de_locale) = g18n.locale("de")
  let de_translator = g18n.translator(de_locale, translations)
  assert "01.01.24" == g18n.format_date(de_translator, date, g18n.Short)
  assert "1. Jan 2024" == g18n.format_date(de_translator, date, g18n.Medium)
  assert "1. Januar 2024 GMT"
    == g18n.format_date(de_translator, date, g18n.Long)
  assert "Montag, 1. Januar 2024 GMT"
    == g18n.format_date(de_translator, date, g18n.Full)

  // Italian
  let assert Ok(it_locale) = g18n.locale("it")
  let it_translator = g18n.translator(it_locale, translations)
  assert "01/01/24" == g18n.format_date(it_translator, date, g18n.Short)
  assert "1 gen 2024" == g18n.format_date(it_translator, date, g18n.Medium)
  assert "1 gennaio 2024 GMT"
    == g18n.format_date(it_translator, date, g18n.Long)
  assert "lunedì, 1 gennaio 2024 GMT"
    == g18n.format_date(it_translator, date, g18n.Full)

  // Russian
  let assert Ok(ru_locale) = g18n.locale("ru")
  let ru_translator = g18n.translator(ru_locale, translations)
  assert "01.01.24" == g18n.format_date(ru_translator, date, g18n.Short)
  assert "1 янв 2024 г." == g18n.format_date(ru_translator, date, g18n.Medium)
  assert "1 январь 2024 г. GMT"
    == g18n.format_date(ru_translator, date, g18n.Long)
  assert "понедельник, 1 январь 2024 г. GMT"
    == g18n.format_date(ru_translator, date, g18n.Full)
}

pub fn asian_languages_date_formatting_test() {
  let date = calendar.Date(2024, calendar.March, 15)
  let translations = g18n.translations()

  // Chinese
  let assert Ok(zh_locale) = g18n.locale("zh")
  let zh_translator = g18n.translator(zh_locale, translations)
  assert "24/03/15" == g18n.format_date(zh_translator, date, g18n.Short)
  assert "2024年3月15日" == g18n.format_date(zh_translator, date, g18n.Medium)
  assert "2024年三月15日 GMT" == g18n.format_date(zh_translator, date, g18n.Long)
  assert "2024年三月15日星期五 GMT" == g18n.format_date(zh_translator, date, g18n.Full)

  // Japanese
  let assert Ok(ja_locale) = g18n.locale("ja")
  let ja_translator = g18n.translator(ja_locale, translations)
  assert "24/03/15" == g18n.format_date(ja_translator, date, g18n.Short)
  assert "2024年3月15日" == g18n.format_date(ja_translator, date, g18n.Medium)
  assert "2024年三月15日 GMT" == g18n.format_date(ja_translator, date, g18n.Long)
  assert "2024年三月15日金曜日 GMT" == g18n.format_date(ja_translator, date, g18n.Full)

  // Korean
  let assert Ok(ko_locale) = g18n.locale("ko")
  let ko_translator = g18n.translator(ko_locale, translations)
  assert "24/03/15" == g18n.format_date(ko_translator, date, g18n.Short)
  assert "2024년 3월 15일" == g18n.format_date(ko_translator, date, g18n.Medium)
  assert "2024년 삼월 15일 GMT" == g18n.format_date(ko_translator, date, g18n.Long)
  assert "2024년 삼월 15일 금요일 GMT"
    == g18n.format_date(ko_translator, date, g18n.Full)
}

pub fn day_of_week_calculation_test() {
  let translations = g18n.translations()
  let assert Ok(en_locale) = g18n.locale("en")
  let en_translator = g18n.translator(en_locale, translations)

  // Test known dates with their correct day of week
  // January 1, 2024 was a Monday
  let monday_date = calendar.Date(2024, calendar.January, 1)

  // December 25, 2023 was a Monday
  let christmas_2023 = calendar.Date(2023, calendar.December, 25)

  // July 4, 2024 was a Thursday
  let july_4th = calendar.Date(2024, calendar.July, 4)

  // February 29, 2024 was a Thursday (leap year)
  let leap_day = calendar.Date(2024, calendar.February, 29)

  // Test with the correct assertions
  assert "Monday, January 1, 2024 GMT"
    == g18n.format_date(en_translator, monday_date, g18n.Full)
  assert "Monday, December 25, 2023 GMT"
    == g18n.format_date(en_translator, christmas_2023, g18n.Full)
  assert "Thursday, July 4, 2024 GMT"
    == g18n.format_date(en_translator, july_4th, g18n.Full)
  assert "Thursday, February 29, 2024 GMT"
    == g18n.format_date(en_translator, leap_day, g18n.Full)

  // Test in different languages for same date
  let assert Ok(pt_locale) = g18n.locale("pt")
  let pt_translator = g18n.translator(pt_locale, translations)
  assert "segunda-feira, 1 de janeiro de 2024 GMT"
    == g18n.format_date(pt_translator, monday_date, g18n.Full)

  let assert Ok(fr_locale) = g18n.locale("fr")
  let fr_translator = g18n.translator(fr_locale, translations)
  assert "lundi 1 janvier 2024 GMT"
    == g18n.format_date(fr_translator, monday_date, g18n.Full)
}

pub fn time_unit_formatting_test() {
  let translations = g18n.translations()

  // English
  let assert Ok(en_locale) = g18n.locale("en")
  let en_translator = g18n.translator(en_locale, translations)
  assert "1 second ago"
    == g18n.format_relative_time(en_translator, g18n.Seconds(1), g18n.Past)
  assert "5 minutes ago"
    == g18n.format_relative_time(en_translator, g18n.Minutes(5), g18n.Past)
  assert "in 2 hours"
    == g18n.format_relative_time(en_translator, g18n.Hours(2), g18n.Future)

  // Spanish
  let assert Ok(es_locale) = g18n.locale("es")
  let es_translator = g18n.translator(es_locale, translations)
  assert "hace 1 segundo"
    == g18n.format_relative_time(es_translator, g18n.Seconds(1), g18n.Past)
  assert "hace 5 minutos"
    == g18n.format_relative_time(es_translator, g18n.Minutes(5), g18n.Past)
  assert "en 2 horas"
    == g18n.format_relative_time(es_translator, g18n.Hours(2), g18n.Future)

  // French
  let assert Ok(fr_locale) = g18n.locale("fr")
  let fr_translator = g18n.translator(fr_locale, translations)
  assert "il y a 1 seconde"
    == g18n.format_relative_time(fr_translator, g18n.Seconds(1), g18n.Past)
  assert "il y a 5 minutes"
    == g18n.format_relative_time(fr_translator, g18n.Minutes(5), g18n.Past)
  assert "dans 2 heures"
    == g18n.format_relative_time(fr_translator, g18n.Hours(2), g18n.Future)

  // German
  let assert Ok(de_locale) = g18n.locale("de")
  let de_translator = g18n.translator(de_locale, translations)
  assert "vor 1 Sekunde"
    == g18n.format_relative_time(de_translator, g18n.Seconds(1), g18n.Past)
  assert "vor 5 Minuten"
    == g18n.format_relative_time(de_translator, g18n.Minutes(5), g18n.Past)
  assert "in 2 Stunden"
    == g18n.format_relative_time(de_translator, g18n.Hours(2), g18n.Future)

  // Russian (with complex pluralization)
  let assert Ok(ru_locale) = g18n.locale("ru")
  let ru_translator = g18n.translator(ru_locale, translations)
  assert "1 секунда назад"
    == g18n.format_relative_time(ru_translator, g18n.Seconds(1), g18n.Past)
  assert "2 секунды назад"
    == g18n.format_relative_time(ru_translator, g18n.Seconds(2), g18n.Past)
  assert "5 секунд назад"
    == g18n.format_relative_time(ru_translator, g18n.Seconds(5), g18n.Past)
  assert "через 1 час"
    == g18n.format_relative_time(ru_translator, g18n.Hours(1), g18n.Future)
  assert "через 3 часа"
    == g18n.format_relative_time(ru_translator, g18n.Hours(3), g18n.Future)
  assert "через 5 часов"
    == g18n.format_relative_time(ru_translator, g18n.Hours(5), g18n.Future)

  // Chinese (no pluralization)
  let assert Ok(zh_locale) = g18n.locale("zh")
  let zh_translator = g18n.translator(zh_locale, translations)
  assert "1秒前"
    == g18n.format_relative_time(zh_translator, g18n.Seconds(1), g18n.Past)
  assert "5分钟前"
    == g18n.format_relative_time(zh_translator, g18n.Minutes(5), g18n.Past)
  assert "2小时后"
    == g18n.format_relative_time(zh_translator, g18n.Hours(2), g18n.Future)

  // Japanese
  let assert Ok(ja_locale) = g18n.locale("ja")
  let ja_translator = g18n.translator(ja_locale, translations)
  assert "1秒前"
    == g18n.format_relative_time(ja_translator, g18n.Seconds(1), g18n.Past)
  assert "5分前"
    == g18n.format_relative_time(ja_translator, g18n.Minutes(5), g18n.Past)
  assert "2時間後"
    == g18n.format_relative_time(ja_translator, g18n.Hours(2), g18n.Future)

  // Korean
  let assert Ok(ko_locale) = g18n.locale("ko")
  let ko_translator = g18n.translator(ko_locale, translations)
  assert "1초 전"
    == g18n.format_relative_time(ko_translator, g18n.Seconds(1), g18n.Past)
  assert "5분 전"
    == g18n.format_relative_time(ko_translator, g18n.Minutes(5), g18n.Past)
  assert "2시간 후"
    == g18n.format_relative_time(ko_translator, g18n.Hours(2), g18n.Future)

  // Arabic (with complex pluralization)
  let assert Ok(ar_locale) = g18n.locale("ar")
  let ar_translator = g18n.translator(ar_locale, translations)
  assert "منذ ثانية واحدة"
    == g18n.format_relative_time(ar_translator, g18n.Seconds(1), g18n.Past)
  assert "منذ ثانيتان"
    == g18n.format_relative_time(ar_translator, g18n.Seconds(2), g18n.Past)
  assert "منذ 3 ثوانٍ"
    == g18n.format_relative_time(ar_translator, g18n.Seconds(3), g18n.Past)
  assert "منذ 11 ثانية"
    == g18n.format_relative_time(ar_translator, g18n.Seconds(11), g18n.Past)

  // Hindi
  let assert Ok(hi_locale) = g18n.locale("hi")
  let hi_translator = g18n.translator(hi_locale, translations)
  assert "1 सेकंड पहले"
    == g18n.format_relative_time(hi_translator, g18n.Seconds(1), g18n.Past)
  assert "5 मिनट पहले"
    == g18n.format_relative_time(hi_translator, g18n.Minutes(5), g18n.Past)
  assert "2 घंटे में"
    == g18n.format_relative_time(hi_translator, g18n.Hours(2), g18n.Future)
}

pub fn month_name_localization_test() {
  let date_jan = calendar.Date(2024, calendar.January, 15)
  let date_may = calendar.Date(2024, calendar.May, 15)
  let date_dec = calendar.Date(2024, calendar.December, 15)
  let translations = g18n.translations()

  // Test month names in different languages
  let assert Ok(en_locale) = g18n.locale("en")
  let en_translator = g18n.translator(en_locale, translations)
  assert "Jan 15, 2024"
    == g18n.format_date(en_translator, date_jan, g18n.Medium)
  assert "May 15, 2024"
    == g18n.format_date(en_translator, date_may, g18n.Medium)
  assert "Dec 15, 2024"
    == g18n.format_date(en_translator, date_dec, g18n.Medium)

  let assert Ok(pt_locale) = g18n.locale("pt")
  let pt_translator = g18n.translator(pt_locale, translations)
  assert "15 de jan de 2024"
    == g18n.format_date(pt_translator, date_jan, g18n.Medium)
  assert "15 de mai de 2024"
    == g18n.format_date(pt_translator, date_may, g18n.Medium)
  assert "15 de dez de 2024"
    == g18n.format_date(pt_translator, date_dec, g18n.Medium)

  let assert Ok(fr_locale) = g18n.locale("fr")
  let fr_translator = g18n.translator(fr_locale, translations)
  assert "15 janv 2024"
    == g18n.format_date(fr_translator, date_jan, g18n.Medium)
  assert "15 mai 2024" == g18n.format_date(fr_translator, date_may, g18n.Medium)
  assert "15 déc 2024" == g18n.format_date(fr_translator, date_dec, g18n.Medium)

  let assert Ok(de_locale) = g18n.locale("de")
  let de_translator = g18n.translator(de_locale, translations)
  assert "15. Jan 2024"
    == g18n.format_date(de_translator, date_jan, g18n.Medium)
  assert "15. Mai 2024"
    == g18n.format_date(de_translator, date_may, g18n.Medium)
  assert "15. Dez 2024"
    == g18n.format_date(de_translator, date_dec, g18n.Medium)

  let assert Ok(ru_locale) = g18n.locale("ru")
  let ru_translator = g18n.translator(ru_locale, translations)
  assert "15 янв 2024 г."
    == g18n.format_date(ru_translator, date_jan, g18n.Medium)
  assert "15 май 2024 г."
    == g18n.format_date(ru_translator, date_may, g18n.Medium)
  assert "15 дек 2024 г."
    == g18n.format_date(ru_translator, date_dec, g18n.Medium)

  // Test Chinese months
  let assert Ok(zh_locale) = g18n.locale("zh")
  let zh_translator = g18n.translator(zh_locale, translations)
  assert "2024年1月15日" == g18n.format_date(zh_translator, date_jan, g18n.Medium)
  assert "2024年5月15日" == g18n.format_date(zh_translator, date_may, g18n.Medium)
  assert "2024年12月15日" == g18n.format_date(zh_translator, date_dec, g18n.Medium)
}

pub fn fallback_language_test() {
  let date = calendar.Date(2024, calendar.June, 1)
  // Saturday
  let translations = g18n.translations()

  // Test unsupported language falls back to numeric format for months
  let assert Ok(unsupported_locale) = g18n.locale("xx")
  // Unsupported language
  let unsupported_translator = g18n.translator(unsupported_locale, translations)

  // Should fall back to default format
  assert "01-06-24"
    == g18n.format_date(unsupported_translator, date, g18n.Short)
  assert "1 06 2024"
    == g18n.format_date(unsupported_translator, date, g18n.Medium)
  assert "1 06 2024 GMT"
    == g18n.format_date(unsupported_translator, date, g18n.Long)

  // June 1, 2024 is a Saturday (day 6), so fallback shows "Day 6"
  assert "Day 6, 1 06 2024 GMT"
    == g18n.format_date(unsupported_translator, date, g18n.Full)
}

pub fn locale_utility_functions_test() {
  let assert Ok(en_us_locale) = g18n.locale("en-US")
  let assert Ok(en_locale) = g18n.locale("en")
  let assert Ok(pt_br_locale) = g18n.locale("pt-BR")

  // Test locale_language
  assert "en" == g18n.locale_language(en_us_locale)
  assert "en" == g18n.locale_language(en_locale)
  assert "pt" == g18n.locale_language(pt_br_locale)

  // Test locale_region
  assert g18n.locale_region(en_us_locale) == Some("US")
  assert g18n.locale_region(en_locale) == None
  assert g18n.locale_region(pt_br_locale) == Some("BR")

  // Test locales_match_language
  assert True == g18n.locales_match_language(en_us_locale, en_locale)
  assert False == g18n.locales_match_language(en_us_locale, pt_br_locale)

  // Test locales_exact_match
  assert False == g18n.locales_exact_match(en_us_locale, en_locale)
  assert True == g18n.locales_exact_match(en_us_locale, en_us_locale)

  // Test locale_language_only
  let en_only = g18n.locale_language_only(en_us_locale)
  assert "en" == g18n.locale_string(en_only)
  assert None == g18n.locale_region(en_only)
}

pub fn translator_accessor_functions_test() {
  let assert Ok(en_locale) = g18n.locale("en-US")
  let assert Ok(fallback_locale) = g18n.locale("en")
  let translations =
    g18n.translations() |> g18n.add_translation("hello", "Hello")
  let fallback_translations =
    g18n.translations() |> g18n.add_translation("goodbye", "Goodbye")

  let translator = g18n.translator(en_locale, translations)
  let translator_with_fallback =
    g18n.with_fallback(translator, fallback_locale, fallback_translations)

  // Test get_locale
  assert "en-US" == g18n.locale_string(g18n.get_locale(translator))
  assert "en-US"
    == g18n.locale_string(g18n.get_locale(translator_with_fallback))

  // Test get_fallback_locale
  assert None == g18n.get_fallback_locale(translator)
  assert Some(fallback_locale)
    == g18n.get_fallback_locale(translator_with_fallback)

  // Test get_translations and get_fallback_translations
  let main_trans = g18n.get_translations(translator_with_fallback)
  let fallback_trans = g18n.get_fallback_translations(translator_with_fallback)

  assert "Hello"
    == g18n.translate(g18n.translator(en_locale, main_trans), "hello")
  // Test fallback translations exist and work correctly
  let assert Some(fb_trans) = fallback_trans
  assert "Goodbye"
    == g18n.translate(g18n.translator(fallback_locale, fb_trans), "goodbye")
}

pub fn string_formatting_functions_test() {
  // Test format_string
  let template = "Hello {name}, you have {count} messages"
  let params =
    g18n.format_params()
    |> g18n.add_param("name", "Alice")
    |> g18n.add_param("count", "5")

  assert "Hello Alice, you have 5 messages"
    == g18n.format_string(template, params)

  // Test extract_placeholders
  let placeholders = g18n.extract_placeholders(template)
  assert ["name", "count"] == placeholders

  let complex_template = "Welcome {user} to {app} version {version}"
  let complex_placeholders = g18n.extract_placeholders(complex_template)
  assert ["user", "app", "version"] == complex_placeholders

  // Test empty template
  let empty_placeholders = g18n.extract_placeholders("No placeholders here")
  assert [] == empty_placeholders
}

pub fn plural_rule_functions_test() {
  // Test individual plural rule functions
  assert g18n.One == g18n.english_plural_rule(1)
  assert g18n.Other == g18n.english_plural_rule(0)
  assert g18n.Other == g18n.english_plural_rule(2)

  assert g18n.Zero == g18n.portuguese_plural_rule(0)
  assert g18n.One == g18n.portuguese_plural_rule(1)
  assert g18n.Other == g18n.portuguese_plural_rule(2)

  assert g18n.One == g18n.russian_plural_rule(1)
  assert g18n.Few == g18n.russian_plural_rule(2)
  assert g18n.Few == g18n.russian_plural_rule(3)
  assert g18n.Few == g18n.russian_plural_rule(4)
  assert g18n.Many == g18n.russian_plural_rule(5)
  assert g18n.Many == g18n.russian_plural_rule(11)

  // Test get_plural_key
  let en_rule = g18n.get_locale_plural_rule("en")
  assert "item.one" == g18n.get_plural_key("item", 1, en_rule)
  assert "item.other" == g18n.get_plural_key("item", 5, en_rule)

  let pt_rule = g18n.get_locale_plural_rule("pt")
  assert "item.zero" == g18n.get_plural_key("item", 0, pt_rule)
  assert "item.one" == g18n.get_plural_key("item", 1, pt_rule)
  assert "item.other" == g18n.get_plural_key("item", 3, pt_rule)

  // Test get_locale_plural_rule
  let unknown_rule = g18n.get_locale_plural_rule("unknown")
  assert g18n.One == unknown_rule(1)
  assert g18n.Other == unknown_rule(5)
}

pub fn individual_number_formatting_test() {
  // Test individual format functions
  assert "1234.56" == g18n.format_decimal(1234.56, 2, "en")

  assert "$29.99" == g18n.format_currency(29.99, "USD", 2, "en")
  assert "R$29.99" == g18n.format_currency(29.99, "BRL", 2, "pt")

  assert "75.0%" == g18n.format_percentage(0.75, 1, "en")

  assert "1.23E+00" == g18n.format_scientific(1.234, 2)

  assert "1.5M" == g18n.format_compact(1_500_000.0, "en")
  assert "2.5K" == g18n.format_compact(2500.0, "en")
}

pub fn time_and_datetime_formatting_test() {
  let assert Ok(en_locale) = g18n.locale("en")
  let assert Ok(pt_locale) = g18n.locale("pt")
  let translations = g18n.translations()
  let en_translator = g18n.translator(en_locale, translations)
  let pt_translator = g18n.translator(pt_locale, translations)

  let time = calendar.TimeOfDay(14, 30, 45, 0)
  let date = calendar.Date(2024, calendar.January, 15)

  // Test format_time
  assert "2:30 PM" == g18n.format_time(en_translator, time, g18n.Short)
  assert "14:30" == g18n.format_time(pt_translator, time, g18n.Short)
  assert "2:30:45 PM" == g18n.format_time(en_translator, time, g18n.Medium)
  assert "14:30:45" == g18n.format_time(pt_translator, time, g18n.Medium)

  // Test format_datetime
  assert "01/15/24 2:30 PM"
    == g18n.format_datetime(en_translator, date, time, g18n.Short)
  assert "15/01/24 14:30"
    == g18n.format_datetime(pt_translator, date, time, g18n.Short)
}

pub fn translate_cardinal_alias_test() {
  let assert Ok(locale) = g18n.locale("en")
  let translations =
    g18n.translations()
    |> g18n.add_translation("item.one", "1 item")
    |> g18n.add_translation("item.other", "{count} items")
  let translator = g18n.translator(locale, translations)

  // translate_cardinal should work exactly like translate_plural
  assert "1 item" == g18n.translate_cardinal(translator, "item", 1)
  assert "{count} items" == g18n.translate_cardinal(translator, "item", 5)
}

pub fn json_export_test() {
  let translations =
    g18n.translations()
    |> g18n.add_translation("hello", "Hello")
    |> g18n.add_translation("user.welcome", "Welcome {name}!")
    |> g18n.add_translation("item.one", "1 item")

  // Test translations_to_json
  let json_output = g18n.translations_to_json(translations)

  // Should be valid JSON containing our translations
  let assert Ok(parsed_back) = g18n.translations_from_json(json_output)

  // Test round-trip: original -> JSON -> back to translations
  let assert Ok(test_locale) = g18n.locale("en")
  let original_translator = g18n.translator(test_locale, translations)
  let parsed_translator = g18n.translator(test_locale, parsed_back)

  assert g18n.translate(original_translator, "hello")
    == g18n.translate(parsed_translator, "hello")
  assert g18n.translate(original_translator, "user.welcome")
    == g18n.translate(parsed_translator, "user.welcome")
  assert g18n.translate(original_translator, "item.one")
    == g18n.translate(parsed_translator, "item.one")
}

pub fn validation_parameter_test() {
  let assert Ok(locale) = g18n.locale("en")
  let translations =
    g18n.translations()
    |> g18n.add_translation("user.welcome", "Welcome {name}!")
    |> g18n.add_translation("user.profile", "Profile for {user} (ID: {id})")
    |> g18n.add_translation("simple.message", "Simple message with no params")

  // Test validate_translation_parameters
  let no_errors =
    g18n.validate_translation_parameters(
      translations,
      "user.welcome",
      ["name"],
      locale,
    )
  assert [] == no_errors

  let missing_param_errors =
    g18n.validate_translation_parameters(
      translations,
      "user.profile",
      ["user"],
      locale,
    )
  assert list.length(missing_param_errors) == 1

  let unused_param_errors =
    g18n.validate_translation_parameters(
      translations,
      "user.welcome",
      ["name", "unused"],
      locale,
    )
  assert list.length(unused_param_errors) == 1

  let missing_translation_errors =
    g18n.validate_translation_parameters(
      translations,
      "nonexistent.key",
      ["param"],
      locale,
    )
  assert list.length(missing_translation_errors) == 1
}

// Tests for high-priority features added
pub fn rtl_ltr_support_test() {
  let assert Ok(english) = g18n.locale("en")
  let assert Ok(arabic) = g18n.locale("ar")
  let assert Ok(hebrew) = g18n.locale("he")
  let assert Ok(persian) = g18n.locale("fa")
  let assert Ok(spanish) = g18n.locale("es")

  // Test RTL languages
  assert g18n.get_text_direction(arabic) == g18n.RTL
  assert g18n.get_text_direction(hebrew) == g18n.RTL
  assert g18n.get_text_direction(persian) == g18n.RTL
  assert g18n.is_rtl(arabic) == True
  assert g18n.is_rtl(hebrew) == True
  assert g18n.get_css_direction(arabic) == "rtl"
  assert g18n.get_css_direction(hebrew) == "rtl"

  // Test LTR languages
  assert g18n.get_text_direction(english) == g18n.LTR
  assert g18n.get_text_direction(spanish) == g18n.LTR
  assert g18n.is_rtl(english) == False
  assert g18n.is_rtl(spanish) == False
  assert g18n.get_css_direction(english) == "ltr"
  assert g18n.get_css_direction(spanish) == "ltr"
}

pub fn locale_negotiation_test() {
  let assert Ok(en) = g18n.locale("en")
  let assert Ok(en_us) = g18n.locale("en-US")
  let assert Ok(es) = g18n.locale("es")
  let assert Ok(fr) = g18n.locale("fr")

  let available = [Ok(en), Ok(en_us), Ok(es), Ok(fr)]

  // Test exact match
  let preferred_exact = [Ok(es)]
  case g18n.negotiate_locale(available, preferred_exact) {
    Some(locale) -> {
      assert g18n.locale_string(locale) == "es"
    }
    None -> panic
  }

  // Test language match (en-GB should match en)
  let assert Ok(en_gb) = g18n.locale("en-GB")
  let preferred_lang_match = [Ok(en_gb)]
  case g18n.negotiate_locale(available, preferred_lang_match) {
    Some(locale) -> {
      assert g18n.locale_language(locale) == "en"
    }
    None -> panic
  }

  // Test no match - should return first available
  let assert Ok(de) = g18n.locale("de")
  let preferred_no_match = [Ok(de)]
  case g18n.negotiate_locale(available, preferred_no_match) {
    Some(locale) -> {
      assert g18n.locale_string(locale) == "en"
      // First available
    }
    None -> panic
  }
}

pub fn accept_language_parsing_test() {
  let parsed = g18n.parse_accept_language("en-US,en;q=0.9,fr;q=0.8")
  assert list.length(parsed) == 3

  case parsed {
    [Ok(first), Ok(second), Ok(third)] -> {
      assert g18n.locale_string(first) == "en-US"
      assert g18n.locale_string(second) == "en"
      assert g18n.locale_string(third) == "fr"
    }
    _ -> panic
  }

  // Test quality scoring
  let assert Ok(en_us) = g18n.locale("en-US")
  let assert Ok(en) = g18n.locale("en")
  let assert Ok(fr) = g18n.locale("fr")

  // Exact match should have highest score
  assert g18n.get_locale_quality_score(en_us, en_us) == 1.0
  // Language match should have lower score
  assert g18n.get_locale_quality_score(en_us, en) == 0.8
  // No match should have zero score
  assert g18n.get_locale_quality_score(en_us, fr) == 0.0
}

pub fn expanded_pluralization_test() {
  // Test Arabic pluralization (6 forms)
  let ar_rule = g18n.get_locale_plural_rule("ar")
  assert ar_rule(0) == g18n.Zero
  assert ar_rule(1) == g18n.One
  assert ar_rule(2) == g18n.Two
  assert ar_rule(5) == g18n.Few
  assert ar_rule(15) == g18n.Many
  assert ar_rule(100) == g18n.Other

  // Test Spanish pluralization
  let es_rule = g18n.get_locale_plural_rule("es")
  assert es_rule(1) == g18n.One
  assert es_rule(0) == g18n.Other
  assert es_rule(5) == g18n.Other

  // Test French pluralization (0 and 1 are singular)
  let fr_rule = g18n.get_locale_plural_rule("fr")
  assert fr_rule(0) == g18n.One
  assert fr_rule(1) == g18n.One
  assert fr_rule(2) == g18n.Other

  // Test German pluralization
  let de_rule = g18n.get_locale_plural_rule("de")
  assert de_rule(1) == g18n.One
  assert de_rule(0) == g18n.Other
  assert de_rule(3) == g18n.Other

  // Test Italian pluralization
  let it_rule = g18n.get_locale_plural_rule("it")
  assert it_rule(1) == g18n.One
  assert it_rule(0) == g18n.Other
  assert it_rule(2) == g18n.Other

  // Test Chinese pluralization (no plurals)
  let zh_rule = g18n.get_locale_plural_rule("zh")
  assert zh_rule(0) == g18n.Other
  assert zh_rule(1) == g18n.Other
  assert zh_rule(100) == g18n.Other

  // Test Japanese pluralization (no plurals)
  let ja_rule = g18n.get_locale_plural_rule("ja")
  assert ja_rule(0) == g18n.Other
  assert ja_rule(1) == g18n.Other
  assert ja_rule(100) == g18n.Other

  // Test Korean pluralization (no plurals)
  let ko_rule = g18n.get_locale_plural_rule("ko")
  assert ko_rule(0) == g18n.Other
  assert ko_rule(1) == g18n.Other
  assert ko_rule(100) == g18n.Other

  // Test Hindi pluralization
  let hi_rule = g18n.get_locale_plural_rule("hi")
  assert hi_rule(0) == g18n.One
  assert hi_rule(1) == g18n.One
  assert hi_rule(2) == g18n.Other
}

pub fn context_sensitive_translation_test() {
  let assert Ok(locale) = g18n.locale("en")
  let translations =
    g18n.translations()
    |> g18n.add_translation("may", "may")
    // auxiliary verb
    |> g18n.add_translation("may@month", "May")
    // month name
    |> g18n.add_translation("may@permission", "allowed to")
    // permission
    |> g18n.add_translation("bank", "bank")
    |> g18n.add_context_translation(
      "bank",
      "financial",
      "financial institution",
    )
    |> g18n.add_context_translation("bank", "river", "riverbank")

  let translator = g18n.translator(locale, translations)

  // Test context translation
  assert g18n.translate_with_context(translator, "may", g18n.NoContext) == "may"
  assert g18n.translate_with_context(translator, "may", g18n.Context("month"))
    == "May"
  assert g18n.translate_with_context(
      translator,
      "may",
      g18n.Context("permission"),
    )
    == "allowed to"

  // Test context with parameters
  let translations_with_params =
    translations
    |> g18n.add_translation("close@door", "Close the {item}")
    |> g18n.add_translation("close@application", "Close {app_name}")

  let translator_with_params = g18n.translator(locale, translations_with_params)
  let params = g18n.format_params() |> g18n.add_param("item", "door")

  assert g18n.translate_with_context_and_params(
      translator_with_params,
      "close",
      g18n.Context("door"),
      params,
    )
    == "Close the door"

  // Test context variants
  let variants = g18n.get_context_variants(translations, "bank")
  assert list.length(variants) == 3
  // bank, bank@financial, bank@river

  // Test missing context falls back to base key
  assert g18n.translate_with_context(translator, "may", g18n.Context("unknown"))
    == "may@unknown"
}

pub fn nested_json_import_test() {
  let nested_json =
    json.object([
      #(
        "ui",
        json.object([
          #(
            "button",
            json.object([
              #("save", json.string("Save")),
              #("cancel", json.string("Cancel")),
            ]),
          ),
        ]),
      ),
    ])

  let assert Ok(translations) =
    g18n.translations_from_nested_json(nested_json |> json.to_string)
  let assert Ok(locale) = g18n.locale("en")
  let translator = g18n.translator(locale, translations)

  // Test that nested keys are flattened correctly
  assert g18n.translate(translator, "ui.button.save") == "Save"
  assert g18n.translate(translator, "ui.button.cancel") == "Cancel"

  let translations =
    g18n.translations()
    |> g18n.add_translation("ui.button.save", "Save")
    |> g18n.add_translation("user.name", "Name")

  let exported = g18n.translations_to_nested_json(translations)
  // Should contain the translations in nested JSON format
  let expected = "{\"ui\":{\"button\":{\"save\":\"Save\"}},\"user\":{\"name\":\"Name\"}}"
  assert exported == expected
}
