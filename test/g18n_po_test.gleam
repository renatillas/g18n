import g18n
import g18n/internal/po
import g18n/locale
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Basic PO parsing tests
pub fn parse_simple_po_entry_test() {
  let po_content =
    "msgid \"hello\"
msgstr \"Hello\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "hello")
  should.equal(entry.msgstr, "Hello")
  should.equal(entry.msgctxt, None)
  should.equal(entry.comments, [])
  should.equal(entry.references, [])
  should.equal(entry.flags, [])
}

pub fn parse_po_entry_with_context_test() {
  let po_content =
    "msgctxt \"greeting\"
msgid \"hello\"
msgstr \"Hi there\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "hello")
  should.equal(entry.msgstr, "Hi there")
  should.equal(entry.msgctxt, Some("greeting"))
}

pub fn parse_po_entry_with_comments_test() {
  let po_content =
    "# Translator comment
#: src/main.gleam:42
#, fuzzy
msgid \"button.save\"
msgstr \"Save\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "button.save")
  should.equal(entry.msgstr, "Save")
  should.equal(entry.comments, ["Translator comment"])
  should.equal(entry.references, ["src/main.gleam:42"])
  should.equal(entry.flags, ["fuzzy"])
}

pub fn parse_multiline_po_entry_test() {
  let po_content =
    "msgid \"long.message\"
msgstr \"This is a very long message that spans \"
\"multiple lines in the PO file format. \"
\"It should be properly concatenated.\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "long.message")
  should.equal(
    entry.msgstr,
    "This is a very long message that spans multiple lines in the PO file format. It should be properly concatenated.",
  )
}

pub fn parse_multiple_po_entries_test() {
  let po_content =
    "# First entry
msgid \"hello\"
msgstr \"Hello\"

# Second entry
msgid \"goodbye\"
msgstr \"Goodbye\"

# Third entry with context
msgctxt \"financial\"
msgid \"bank\"
msgstr \"Financial Institution\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 3)

  let assert [entry1, entry2, entry3] = entries

  should.equal(entry1.msgid, "hello")
  should.equal(entry1.msgstr, "Hello")
  should.equal(entry1.comments, ["First entry"])

  should.equal(entry2.msgid, "goodbye")
  should.equal(entry2.msgstr, "Goodbye")
  should.equal(entry2.comments, ["Second entry"])

  should.equal(entry3.msgid, "bank")
  should.equal(entry3.msgstr, "Financial Institution")
  should.equal(entry3.msgctxt, Some("financial"))
  should.equal(entry3.comments, ["Third entry with context"])
}

pub fn parse_empty_po_file_test() {
  let po_content = ""
  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(entries, [])
}

pub fn parse_po_with_only_comments_test() {
  let po_content =
    "# Just comments
# No actual entries
#: some/file.gleam:1"

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(entries, [])
}

pub fn parse_escape_sequences_test() {
  let po_content =
    "msgid \"test.escape\"
msgstr \"Line one\\nLine two\\tTabbed\\\"Quoted\\\\\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgstr, "Line one\nLine two\tTabbed\"Quoted\\")
}

// Error handling tests
pub fn parse_invalid_escape_sequence_test() {
  let po_content =
    "msgid \"test\"
msgstr \"Invalid escape \\x sequence\""

  let assert Error(po.InvalidEscapeSequence("\\x")) =
    po.parse_po_content(po_content)
}

pub fn parse_missing_msgid_test() {
  let po_content = "msgstr \"Hello\""
  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(entries, [])
  // Invalid entries are skipped, resulting in empty list
}

pub fn parse_missing_msgstr_test() {
  let po_content = "msgid \"hello\""
  let assert Error(po.MissingMsgstr) = po.parse_po_content(po_content)
}

pub fn parse_malformed_quoted_string_test() {
  let po_content =
    "msgid hello
msgstr \"Hello\""

  let assert Error(po.InvalidFormat(_)) = po.parse_po_content(po_content)
}

// Conversion tests
pub fn entries_to_translations_test() {
  let entries = [
    po.PoEntry(
      msgid: "hello",
      msgstr: "Hello",
      msgctxt: None,
      comments: [],
      references: [],
      flags: [],
    ),
    po.PoEntry(
      msgid: "bank",
      msgstr: "Financial Institution",
      msgctxt: Some("financial"),
      comments: [],
      references: [],
      flags: [],
    ),
    po.PoEntry(
      msgid: "bank",
      msgstr: "Riverbank",
      msgctxt: Some("river"),
      comments: [],
      references: [],
      flags: [],
    ),
  ]

  let translations_dict = po.entries_to_translations(entries)

  should.equal(dict.get(translations_dict, "hello"), Ok("Hello"))
  should.equal(
    dict.get(translations_dict, "bank@financial"),
    Ok("Financial Institution"),
  )
  should.equal(dict.get(translations_dict, "bank@river"), Ok("Riverbank"))
  should.equal(dict.size(translations_dict), 3)
}

// Integration with g18n tests
pub fn translations_from_po_integration_test() {
  let po_content =
    "msgid \"ui.button.save\"
msgstr \"Save\"

msgctxt \"financial\"
msgid \"bank\"
msgstr \"Bank Institution\"

msgid \"welcome\"
msgstr \"Welcome {name}!\""

  let assert Ok(translations) = g18n.translations_from_po(po_content)
  let assert Ok(locale) = locale.new("en")
  let translator = g18n.new_translator(locale, translations)

  // Test basic translation
  should.equal(g18n.translate(translator, "ui.button.save"), "Save")

  // Test context translation
  should.equal(
    g18n.translate_with_context(translator, "bank", g18n.Context("financial")),
    "Bank Institution",
  )

  // Test parameterized translation
  let params = g18n.new_format_params() |> g18n.add_param("name", "Alice")
  should.equal(
    g18n.translate_with_params(translator, "welcome", params),
    "Welcome Alice!",
  )
}

pub fn translations_to_po_export_test() {
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("hello", "Hello")
    |> g18n.add_translation("goodbye", "Goodbye")
    |> g18n.add_context_translation(
      "bank",
      "financial",
      "Financial Institution",
    )

  let po_content = g18n.translations_to_po(translations)

  // Should contain all entries
  should.be_true(po_content |> string.contains("msgid \"hello\""))
  should.be_true(po_content |> string.contains("msgstr \"Hello\""))
  should.be_true(po_content |> string.contains("msgid \"goodbye\""))
  should.be_true(po_content |> string.contains("msgstr \"Goodbye\""))
  should.be_true(po_content |> string.contains("msgctxt \"financial\""))
  should.be_true(po_content |> string.contains("msgid \"bank\""))
  should.be_true(
    po_content |> string.contains("msgstr \"Financial Institution\""),
  )
}

pub fn po_roundtrip_test() {
  let original_po =
    "# Test comment
#: src/test.gleam:1
msgid \"ui.button.save\"
msgstr \"Save\"

msgctxt \"greeting\"
msgid \"hello\"
msgstr \"Hi there\"

msgid \"multiline\"
msgstr \"Line one \"
\"Line two\""

  // Parse PO to translations
  let assert Ok(translations) = g18n.translations_from_po(original_po)

  // Convert back to PO
  let exported_po = g18n.translations_to_po(translations)

  // Parse the exported PO again
  let assert Ok(parsed_translations) = g18n.translations_from_po(exported_po)

  // Create translators and verify they work the same
  let assert Ok(locale) = locale.new("en")
  let translator1 = g18n.new_translator(locale, translations)
  let translator2 = g18n.new_translator(locale, parsed_translations)

  should.equal(
    g18n.translate(translator1, "ui.button.save"),
    g18n.translate(translator2, "ui.button.save"),
  )
  should.equal(
    g18n.translate_with_context(translator1, "hello", g18n.Context("greeting")),
    g18n.translate_with_context(translator2, "hello", g18n.Context("greeting")),
  )
  should.equal(
    g18n.translate(translator1, "multiline"),
    g18n.translate(translator2, "multiline"),
  )
}

// Edge cases and comprehensive parsing tests
pub fn parse_po_with_empty_msgstr_test() {
  let po_content =
    "msgid \"empty\"
msgstr \"\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "empty")
  should.equal(entry.msgstr, "")
}

pub fn parse_po_with_special_characters_test() {
  let po_content =
    "msgid \"special.chars\"
msgstr \"Héllö Wörld! 你好 🌍\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgstr, "Héllö Wörld! 你好 🌍")
}

pub fn parse_po_with_mixed_comments_test() {
  let po_content =
    "# Translator comment 1
#: reference1.gleam:10
# Translator comment 2  
#, flag1
# Translator comment 3
#: reference2.gleam:20
#, flag2
msgid \"complex\"
msgstr \"Complex entry\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.comments, [
    "Translator comment 1",
    "Translator comment 2",
    "Translator comment 3",
  ])
  should.equal(entry.references, ["reference1.gleam:10", "reference2.gleam:20"])
  should.equal(entry.flags, ["flag1", "flag2"])
}

pub fn parse_po_with_blank_lines_test() {
  let po_content =
    "

# Comment after blank lines
msgid \"test1\"
msgstr \"Test 1\"


msgid \"test2\"
msgstr \"Test 2\"

"

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 2)

  let assert [entry1, entry2] = entries
  should.equal(entry1.msgid, "test1")
  should.equal(entry1.msgstr, "Test 1")
  should.equal(entry2.msgid, "test2")
  should.equal(entry2.msgstr, "Test 2")
}

pub fn parse_po_complex_multiline_test() {
  let po_content =
    "msgid \"\"
\"This is a multiline msgid \"
\"that starts with empty string \"
\"and continues on multiple lines.\"
msgstr \"\"
\"This is also a multiline msgstr \"
\"with multiple continuation lines \"
\"to test proper parsing.\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(
    entry.msgid,
    "This is a multiline msgid that starts with empty string and continues on multiple lines.",
  )
  should.equal(
    entry.msgstr,
    "This is also a multiline msgstr with multiple continuation lines to test proper parsing.",
  )
}

pub fn large_po_file_test() {
  // Test with a larger PO file to ensure performance and correctness
  let entries_count = 100
  let po_lines =
    list.range(1, entries_count)
    |> list.map(fn(i) {
      let key = "key" <> int.to_string(i)
      let value = "Value " <> int.to_string(i)
      "msgid \"" <> key <> "\"\nmsgstr \"" <> value <> "\""
    })
    |> string.join("\n\n")

  let assert Ok(entries) = po.parse_po_content(po_lines)
  should.equal(list.length(entries), entries_count)

  // Check first and last entries
  let assert [first, ..] = entries
  should.equal(first.msgid, "key1")
  should.equal(first.msgstr, "Value 1")

  let assert Ok(last) = list.last(entries)
  should.equal(last.msgid, "key100")
  should.equal(last.msgstr, "Value 100")
}

pub fn error_propagation_test() {
  // Test invalid escape sequence - should error
  case po.parse_po_content("msgid \"test\"\nmsgstr \"invalid \\z escape\"") {
    Error(_) -> Nil
    // Expected error
    Ok(_) -> panic as "Expected parsing error for invalid escape"
  }

  // Test missing msgstr - should error
  case po.parse_po_content("msgid \"missing msgstr\"") {
    Error(_) -> Nil
    // Expected error  
    Ok(_) -> panic as "Expected parsing error for missing msgstr"
  }

  // Test unquoted msgid - should error
  case po.parse_po_content("msgid unquoted\nmsgstr \"test\"") {
    Error(_) -> Nil
    // Expected error
    Ok(_) -> panic as "Expected parsing error for unquoted msgid"
  }
}
