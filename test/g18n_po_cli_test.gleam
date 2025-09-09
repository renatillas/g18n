import g18n
import g18n/locale
import g18n/po
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Helper function to create test PO file content
fn create_test_po_content() -> String {
  "# Test translation file
#: src/components/Button.gleam:12
msgid \"ui.button.save\"
msgstr \"Save\"

#: src/components/Button.gleam:15
msgid \"ui.button.cancel\"
msgstr \"Cancel\"

# User interface strings
msgid \"user.welcome\"
msgstr \"Welcome {name}!\"

# Context-sensitive translations
msgctxt \"financial\"
msgid \"bank\"
msgstr \"Financial Institution\"

msgctxt \"river\"
msgid \"bank\"
msgstr \"Riverbank\"

# Multiline message
msgid \"help.text\"
msgstr \"This is a long help text that spans \"
\"multiple lines to demonstrate the \"
\"multiline PO file format handling.\""
}

// Test basic PO functionality in CLI context
pub fn basic_po_cli_test() {
  let po_content =
    "msgid \"hello\"
msgstr \"Hello World\""

  let assert Ok(translations) = g18n.translations_from_po(po_content)
  let assert Ok(locale) = locale.new("en")
  let translator = g18n.new_translator(locale, translations)

  should.equal(g18n.translate(translator, "hello"), "Hello World")
}

// Test PO file parsing with real-world examples
pub fn complex_po_parsing_test() {
  let po_content = create_test_po_content()
  let assert Ok(translations) = g18n.translations_from_po(po_content)
  let assert Ok(locale) = locale.new("en")
  let translator = g18n.new_translator(locale, translations)

  // Test all translation types
  should.equal(g18n.translate(translator, "ui.button.save"), "Save")
  should.equal(g18n.translate(translator, "ui.button.cancel"), "Cancel")

  let params = g18n.new_format_params() |> g18n.add_param("name", "Alice")
  should.equal(
    g18n.translate_with_params(translator, "user.welcome", params),
    "Welcome Alice!",
  )

  should.equal(
    g18n.translate_with_context(translator, "bank", g18n.Context("financial")),
    "Financial Institution",
  )
  should.equal(
    g18n.translate_with_context(translator, "bank", g18n.Context("river")),
    "Riverbank",
  )

  should.equal(
    g18n.translate(translator, "help.text"),
    "This is a long help text that spans multiple lines to demonstrate the multiline PO file format handling.",
  )
}

// Test PO export functionality produces valid PO files
pub fn po_export_format_validation_test() {
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("simple", "Simple translation")
    |> g18n.add_translation("with.dots", "Translation with dots")
    |> g18n.add_context_translation("ambiguous", "context1", "First meaning")
    |> g18n.add_context_translation("ambiguous", "context2", "Second meaning")
    |> g18n.add_translation("multiline", "Line one\nLine two\tWith tab")

  let po_output = g18n.translations_to_po(translations)

  // Verify basic structure
  should.be_true(string.contains(po_output, "msgid \"simple\""))
  should.be_true(string.contains(po_output, "msgstr \"Simple translation\""))

  // Verify dotted keys work
  should.be_true(string.contains(po_output, "msgid \"with.dots\""))

  // Verify contexts are properly exported
  should.be_true(string.contains(po_output, "msgctxt \"context1\""))
  should.be_true(string.contains(po_output, "msgctxt \"context2\""))
  should.be_true(string.contains(po_output, "msgid \"ambiguous\""))

  // Verify escape sequences in export
  should.be_true(string.contains(po_output, "Line one\\nLine two\\tWith tab"))

  // Verify the exported PO can be parsed back correctly
  let assert Ok(parsed_translations) = g18n.translations_from_po(po_output)
  let assert Ok(locale) = locale.new("en")
  let original_translator = g18n.new_translator(locale, translations)
  let parsed_translator = g18n.new_translator(locale, parsed_translations)

  // All translations should be identical
  should.equal(
    g18n.translate(original_translator, "simple"),
    g18n.translate(parsed_translator, "simple"),
  )
  should.equal(
    g18n.translate_with_context(
      original_translator,
      "ambiguous",
      g18n.Context("context1"),
    ),
    g18n.translate_with_context(
      parsed_translator,
      "ambiguous",
      g18n.Context("context1"),
    ),
  )
  should.equal(
    g18n.translate(original_translator, "multiline"),
    g18n.translate(parsed_translator, "multiline"),
  )
}

// Test PO format compatibility with gettext standard
pub fn gettext_compatibility_test() {
  // Test standard gettext PO file features
  let gettext_po =
    "# SOME DESCRIPTIVE TITLE.
# Copyright (C) YEAR THE PACKAGE'S COPYRIGHT HOLDER
# This file is distributed under the same license as the PACKAGE package.
# FIRST AUTHOR <EMAIL@ADDRESS>, YEAR.
#
#, fuzzy
msgid \"\"
msgstr \"\"
\"Project-Id-Version: PACKAGE VERSION\\n\"
\"Report-Msgid-Bugs-To: \\n\"
\"POT-Creation-Date: 2024-01-01 12:00+0000\\n\"
\"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\\n\"
\"Last-Translator: FULL NAME <EMAIL@ADDRESS>\\n\"
\"Language-Team: LANGUAGE <LL@li.org>\\n\"
\"Language: \\n\"
\"MIME-Version: 1.0\\n\"
\"Content-Type: text/plain; charset=UTF-8\\n\"
\"Content-Transfer-Encoding: 8bit\\n\"

#: main.c:42
msgid \"Hello, world!\"
msgstr \"¡Hola, mundo!\"

#: main.c:50
#, c-format
msgid \"You have %d new messages.\"
msgstr \"Tienes %d mensajes nuevos.\"

msgid \"File\"
msgstr \"Archivo\"

msgid \"Edit\"
msgstr \"Editar\""

  // Should parse without errors (header entry will be treated as regular entry)
  let assert Ok(entries) = po.parse_po_content(gettext_po)
  should.be_true(list.length(entries) >= 4)

  // Find the actual content entries (not header)
  let content_entries = list.filter(entries, fn(entry) { entry.msgid != "" })

  should.be_true(list.length(content_entries) >= 3)

  // Verify parsing of actual translations
  let hello_entry =
    list.find(content_entries, fn(entry) { entry.msgid == "Hello, world!" })
  should.equal(
    hello_entry,
    Ok(
      po.PoEntry(
        msgid: "Hello, world!",
        msgstr: "¡Hola, mundo!",
        msgctxt: option.None,
        comments: [],
        references: ["main.c:42"],
        flags: [],
      ),
    ),
  )
}

// Test error handling in PO parsing
pub fn po_error_handling_comprehensive_test() {
  // Test missing msgstr
  case g18n.translations_from_po("msgid \"test\"") {
    Error(_) -> Nil
    // Expected
    Ok(_) -> panic as { "Expected error for missing msgstr" }
  }

  // Test missing msgid - now returns empty list instead of error
  case g18n.translations_from_po("msgstr \"test\"") {
    Ok(_) -> Nil
    // Expected - invalid entries are skipped
    Error(_) -> panic as { "Expected success for missing msgid (gets skipped)" }
  }

  // Test invalid escape sequence
  case
    g18n.translations_from_po("msgid \"test\"\nmsgstr \"invalid \\q escape\"")
  {
    Error(_) -> Nil
    // Expected
    Ok(_) -> panic as { "Expected error for invalid escape" }
  }

  // Test valid empty strings
  case g18n.translations_from_po("msgid \"\"\nmsgstr \"\"") {
    Ok(_) -> Nil
    // Expected to work
    Error(_) -> panic as { "Expected success for empty strings" }
  }
}

// Test performance with large PO files
pub fn large_po_file_performance_test() {
  // Generate a large PO file content
  let entries_count = 1000
  let large_po_content =
    list.range(1, entries_count)
    |> list.map(fn(i) {
      let key = "key." <> int.to_string(i)
      let value = "Translation value " <> int.to_string(i) <> " with some text"
      let comment = "# Comment for entry " <> int.to_string(i)
      let reference =
        "#: src/file" <> int.to_string(i % 10) <> ".gleam:" <> int.to_string(i)

      comment
      <> "\n"
      <> reference
      <> "\n"
      <> "msgid \""
      <> key
      <> "\"\n"
      <> "msgstr \""
      <> value
      <> "\""
    })
    |> string.join("\n\n")

  // Should parse successfully
  let assert Ok(translations) = g18n.translations_from_po(large_po_content)
  let assert Ok(locale) = locale.new("en")
  let translator = g18n.new_translator(locale, translations)

  // Test random access to entries
  should.equal(
    g18n.translate(translator, "key.1"),
    "Translation value 1 with some text",
  )
  should.equal(
    g18n.translate(translator, "key.500"),
    "Translation value 500 with some text",
  )
  should.equal(
    g18n.translate(translator, "key.1000"),
    "Translation value 1000 with some text",
  )

  // Test export performance
  let exported_po = g18n.translations_to_po(translations)
  should.be_true(string.length(exported_po) > 0)

  // Verify exported content can be parsed back
  let assert Ok(_) = g18n.translations_from_po(exported_po)
}

// Test Unicode and special character handling
pub fn unicode_handling_test() {
  let unicode_po =
    "msgid \"unicode.test\"
msgstr \"Héllo Wörld! 你好世界 🌍 العالم здравствуй мир\"

msgid \"emoji.test\" 
msgstr \"🚀 🌟 ✨ 🎉 🔥 💡 🌈\"

msgid \"rtl.test\"
msgstr \"مرحبا بالعالم! שלום עולם!\"

msgid \"special.chars\"
msgstr \"Special: @#$%^&*()_+-={}[]|\\\\;'<>?,./~`\""

  let assert Ok(translations) = g18n.translations_from_po(unicode_po)
  let assert Ok(locale) = locale.new("en")
  let translator = g18n.new_translator(locale, translations)

  should.equal(
    g18n.translate(translator, "unicode.test"),
    "Héllo Wörld! 你好世界 🌍 العالم здравствуй мир",
  )
  should.equal(g18n.translate(translator, "emoji.test"), "🚀 🌟 ✨ 🎉 🔥 💡 🌈")
  should.equal(
    g18n.translate(translator, "rtl.test"),
    "مرحبا بالعالم! שלום עולם!",
  )
  should.equal(
    g18n.translate(translator, "special.chars"),
    "Special: @#$%^&*()_+-={}[]|\\;'<>?,./~`",
  )

  // Test roundtrip with Unicode
  let exported = g18n.translations_to_po(translations)
  let assert Ok(reimported) = g18n.translations_from_po(exported)
  let reimported_translator = g18n.new_translator(locale, reimported)

  should.equal(
    g18n.translate(translator, "unicode.test"),
    g18n.translate(reimported_translator, "unicode.test"),
  )
}

// Test integration with existing translation workflow
pub fn translation_workflow_integration_test() {
  // Test that PO translations work seamlessly with existing g18n features
  let po_content =
    "msgid \"item.one\"
msgstr \"1 item\"

msgid \"item.other\"
msgstr \"{count} items\"

msgid \"greeting\"
msgstr \"Hello {name}, you have {count} notifications.\"

msgctxt \"button\"
msgid \"close\"
msgstr \"Close\"

msgctxt \"window\"
msgid \"close\"
msgstr \"Close Window\""

  let assert Ok(translations) = g18n.translations_from_po(po_content)
  let assert Ok(locale) = locale.new("en")
  let translator = g18n.new_translator(locale, translations)

  // Test pluralization
  should.equal(g18n.translate_plural(translator, "item", 1), "1 item")
  should.equal(g18n.translate_plural(translator, "item", 5), "5 items")

  // Test complex parameter substitution
  let params =
    g18n.new_format_params()
    |> g18n.add_param("name", "Alice")
    |> g18n.add_param("count", "3")
  should.equal(
    g18n.translate_with_params(translator, "greeting", params),
    "Hello Alice, you have 3 notifications.",
  )

  // Test context disambiguation  
  should.equal(
    g18n.translate_with_context(translator, "close", g18n.Context("button")),
    "Close",
  )
  should.equal(
    g18n.translate_with_context(translator, "close", g18n.Context("window")),
    "Close Window",
  )

  // Test fallback behavior
  should.equal(g18n.translate(translator, "nonexistent.key"), "nonexistent.key")
}

// Test CLI-like scenarios
pub fn cli_simulation_test() {
  // Simulate what the CLI would do with PO files
  let test_po_files = [
    #("en", create_test_po_content()),
    #(
      "es",
      "msgid \"ui.button.save\"\nmsgstr \"Guardar\"\n\nmsgid \"user.welcome\"\nmsgstr \"¡Bienvenido {name}!\"",
    ),
    #(
      "fr",
      "msgid \"ui.button.save\"\nmsgstr \"Enregistrer\"\n\nmsgid \"user.welcome\"\nmsgstr \"Bienvenue {name}!\"",
    ),
  ]

  // Process each "file" as the CLI would
  let locale_translators =
    list.try_map(test_po_files, fn(file_data) {
      let #(locale_code, po_content) = file_data
      case g18n.translations_from_po(po_content) {
        Ok(translations) ->
          case locale.new(locale_code) {
            Ok(loc) ->
              Ok(#(locale_code, g18n.new_translator(loc, translations)))
            Error(_) -> Error("Failed to create locale")
          }
        Error(e) -> Error(e)
      }
    })

  let assert Ok(translators) = locale_translators
  should.equal(list.length(translators), 3)

  // Verify each translator works correctly
  let assert Ok(#("en", en_translator)) =
    list.find(translators, fn(t) { t.0 == "en" })
  let assert Ok(#("es", es_translator)) =
    list.find(translators, fn(t) { t.0 == "es" })
  let assert Ok(#("fr", fr_translator)) =
    list.find(translators, fn(t) { t.0 == "fr" })

  should.equal(g18n.translate(en_translator, "ui.button.save"), "Save")
  should.equal(g18n.translate(es_translator, "ui.button.save"), "Guardar")
  should.equal(g18n.translate(fr_translator, "ui.button.save"), "Enregistrer")

  // Test parameterized translations across locales
  let params = g18n.new_format_params() |> g18n.add_param("name", "Maria")
  should.equal(
    g18n.translate_with_params(en_translator, "user.welcome", params),
    "Welcome Maria!",
  )
  should.equal(
    g18n.translate_with_params(es_translator, "user.welcome", params),
    "¡Bienvenido Maria!",
  )
  should.equal(
    g18n.translate_with_params(fr_translator, "user.welcome", params),
    "Bienvenue Maria!",
  )
}
