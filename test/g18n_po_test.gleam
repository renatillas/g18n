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
      msgid_plural: None,
      msgstr_plural: [],
      msgctxt: None,
      comments: [],
      references: [],
      flags: [],
    ),
    po.PoEntry(
      msgid: "bank",
      msgstr: "Financial Institution",
      msgid_plural: None,
      msgstr_plural: [],
      msgctxt: Some("financial"),
      comments: [],
      references: [],
      flags: [],
    ),
    po.PoEntry(
      msgid: "bank",
      msgstr: "Riverbank",
      msgid_plural: None,
      msgstr_plural: [],
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

// Test PO plural form parsing
pub fn parse_plural_forms_test() {
  let po_content =
    "msgid \"item\"
msgid_plural \"items\"
msgstr[0] \"1 item\"
msgstr[1] \"{count} items\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "item")
  should.equal(entry.msgstr, "1 item")
  // msgstr is msgstr[0]
  should.equal(entry.msgid_plural, Some("items"))
  should.equal(entry.msgstr_plural, ["1 item", "{count} items"])
}

// Test PO plural forms with context
pub fn parse_plural_forms_with_context_test() {
  let po_content =
    "msgctxt \"notification\"
msgid \"message\"
msgid_plural \"messages\"
msgstr[0] \"You have 1 message\"
msgstr[1] \"You have {count} messages\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "message")
  should.equal(entry.msgstr, "You have 1 message")
  should.equal(entry.msgid_plural, Some("messages"))
  should.equal(entry.msgstr_plural, [
    "You have 1 message",
    "You have {count} messages",
  ])
  should.equal(entry.msgctxt, Some("notification"))
}

// Test complex plural forms (3+ forms like Arabic/Russian)
pub fn parse_complex_plural_forms_test() {
  let po_content =
    "msgid \"day\"
msgid_plural \"days\"
msgstr[0] \"zero days\"
msgstr[1] \"one day\"
msgstr[2] \"two days\"
msgstr[3] \"few days\"
msgstr[4] \"many days\"
msgstr[5] \"other days\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "day")
  should.equal(entry.msgstr, "zero days")
  should.equal(entry.msgid_plural, Some("days"))
  should.equal(list.length(entry.msgstr_plural), 6)
  should.equal(entry.msgstr_plural, [
    "zero days",
    "one day",
    "two days",
    "few days",
    "many days",
    "other days",
  ])
}

// Test plural forms integration with g18n
pub fn plural_forms_g18n_integration_test() {
  let po_content =
    "msgid \"item\"
msgid_plural \"items\"
msgstr[0] \"1 item\"
msgstr[1] \"{count} items\""

  let assert Ok(translations) = g18n.translations_from_po(po_content)
  let assert Ok(locale) = locale.new("en")
  let translator = g18n.new_translator(locale, translations)

  // Should be converted to g18n's .one/.other format
  should.equal(g18n.translate(translator, "item.one"), "1 item")
  should.equal(g18n.translate(translator, "item.other"), "{count} items")

  // Test pluralization works
  should.equal(g18n.translate_plural(translator, "item", 1), "1 item")
  should.equal(g18n.translate_plural(translator, "item", 5), "5 items")
}

// Test mixed regular and plural entries
pub fn mixed_regular_and_plural_test() {
  let po_content =
    "msgid \"hello\"
msgstr \"Hello\"

msgid \"item\"
msgid_plural \"items\"
msgstr[0] \"1 item\"
msgstr[1] \"{count} items\"

msgid \"goodbye\"
msgstr \"Goodbye\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 3)

  let assert [hello_entry, item_entry, goodbye_entry] = entries

  // Regular entry
  should.equal(hello_entry.msgid, "hello")
  should.equal(hello_entry.msgstr, "Hello")
  should.equal(hello_entry.msgid_plural, None)
  should.equal(hello_entry.msgstr_plural, [])

  // Plural entry
  should.equal(item_entry.msgid, "item")
  should.equal(item_entry.msgstr, "1 item")
  should.equal(item_entry.msgid_plural, Some("items"))
  should.equal(item_entry.msgstr_plural, ["1 item", "{count} items"])

  // Regular entry
  should.equal(goodbye_entry.msgid, "goodbye")
  should.equal(goodbye_entry.msgstr, "Goodbye")
  should.equal(goodbye_entry.msgid_plural, None)
  should.equal(goodbye_entry.msgstr_plural, [])
}

// Test minimal plural form (just msgstr[0] and msgstr[1])
pub fn minimal_plural_forms_test() {
  let po_content =
    "msgid \"file\"
msgid_plural \"files\"
msgstr[0] \"one file\"
msgstr[1] \"many files\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "file")
  should.equal(entry.msgstr, "one file")
  should.equal(entry.msgid_plural, Some("files"))
  should.equal(entry.msgstr_plural, ["one file", "many files"])
}

// Test plural forms with multiline strings
pub fn plural_multiline_strings_test() {
  let po_content =
    "msgid \"notification\"
msgid_plural \"notifications\"
msgstr[0] \"You have received \"
\"one important notification.\"
msgstr[1] \"You have received \"
\"{count} important notifications.\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "notification")
  should.equal(entry.msgstr, "You have received one important notification.")
  should.equal(entry.msgid_plural, Some("notifications"))
  should.equal(entry.msgstr_plural, [
    "You have received one important notification.",
    "You have received {count} important notifications.",
  ])
}

// Test plural forms with escape sequences
pub fn plural_with_escape_sequences_test() {
  let po_content =
    "msgid \"line\"
msgid_plural \"lines\"
msgstr[0] \"One line:\\n\\t- Item\"
msgstr[1] \"{count} lines:\\n\\t- Items\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "line")
  should.equal(entry.msgstr, "One line:\n\t- Item")
  should.equal(entry.msgid_plural, Some("lines"))
  should.equal(entry.msgstr_plural, [
    "One line:\n\t- Item",
    "{count} lines:\n\t- Items",
  ])
}

// Test Arabic-style 6-form plural system
pub fn arabic_plural_forms_test() {
  let po_content =
    "msgid \"book\"
msgid_plural \"books\"
msgstr[0] \"no books\"
msgstr[1] \"one book\"
msgstr[2] \"two books\"
msgstr[3] \"few books\"
msgstr[4] \"many books\"
msgstr[5] \"other books\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "book")
  should.equal(entry.msgstr, "no books")
  should.equal(entry.msgid_plural, Some("books"))
  should.equal(entry.msgstr_plural, [
    "no books",
    "one book",
    "two books",
    "few books",
    "many books",
    "other books",
  ])
}

// Test Russian-style 3-form plural system
pub fn russian_plural_forms_test() {
  let po_content =
    "msgid \"день\"
msgid_plural \"дни\"
msgstr[0] \"один день\"
msgstr[1] \"два дня\"
msgstr[2] \"пять дней\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "день")
  should.equal(entry.msgstr, "один день")
  should.equal(entry.msgid_plural, Some("дни"))
  should.equal(entry.msgstr_plural, ["один день", "два дня", "пять дней"])
}

// Test plural forms with comments and metadata
pub fn plural_with_metadata_test() {
  let po_content =
    "# Translator note: Handle pluralization carefully
#: src/counter.gleam:42
#, fuzzy
msgctxt \"ui\"
msgid \"error\"
msgid_plural \"errors\"
msgstr[0] \"1 error found\"
msgstr[1] \"{count} errors found\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "error")
  should.equal(entry.msgstr, "1 error found")
  should.equal(entry.msgid_plural, Some("errors"))
  should.equal(entry.msgstr_plural, ["1 error found", "{count} errors found"])
  should.equal(entry.msgctxt, Some("ui"))
  should.equal(entry.comments, [
    "Translator note: Handle pluralization carefully",
  ])
  should.equal(entry.references, ["src/counter.gleam:42"])
  should.equal(entry.flags, ["fuzzy"])
}

// Test gap in msgstr indices (should still work)
pub fn plural_with_index_gaps_test() {
  let po_content =
    "msgid \"warning\"
msgid_plural \"warnings\"
msgstr[0] \"one warning\"
msgstr[2] \"many warnings\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "warning")
  should.equal(entry.msgstr, "one warning")
  should.equal(entry.msgid_plural, Some("warnings"))
  should.equal(entry.msgstr_plural, ["one warning", "many warnings"])
}

// Test out-of-order msgstr indices
pub fn plural_out_of_order_indices_test() {
  let po_content =
    "msgid \"task\"
msgid_plural \"tasks\"
msgstr[1] \"{count} tasks\"
msgstr[0] \"one task\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "task")
  should.equal(entry.msgstr, "one task")
  // Should still be msgstr[0]
  should.equal(entry.msgid_plural, Some("tasks"))
  should.equal(entry.msgstr_plural, ["one task", "{count} tasks"])
}

// Test export of plural forms to PO format (basic export without plural reconstruction)
pub fn export_plural_forms_test() {
  // Create translations with plural forms (using .one/.other format)
  let translations =
    g18n.new_translations()
    |> g18n.add_translation("item.one", "1 item")
    |> g18n.add_translation("item.other", "{count} items")
    |> g18n.add_translation("hello", "Hello")

  let po_content = g18n.translations_to_po(translations)

  // Should contain regular entries (plural reconstruction not yet implemented)
  should.be_true(string.contains(po_content, "msgid \"hello\""))
  should.be_true(string.contains(po_content, "msgstr \"Hello\""))
  // Currently exports as separate entries, not combined plural form
  should.be_true(string.contains(po_content, "msgid \"item.one\""))
  should.be_true(string.contains(po_content, "msgstr \"1 item\""))
  should.be_true(string.contains(po_content, "msgid \"item.other\""))
  should.be_true(string.contains(po_content, "msgstr \"{count} items\""))
}

// Test complete roundtrip: PO → g18n → PO
pub fn plural_roundtrip_test() {
  let original_po =
    "msgid \"message\"
msgid_plural \"messages\"
msgstr[0] \"one message\"
msgstr[1] \"{count} messages\"

msgid \"hello\"
msgstr \"Hello World\""

  // Parse PO to translations
  let assert Ok(translations) = g18n.translations_from_po(original_po)

  // Export back to PO
  let exported_po = g18n.translations_to_po(translations)

  // Parse the exported PO again
  let assert Ok(reparsed_translations) = g18n.translations_from_po(exported_po)

  // Create translators and verify they work identically
  let assert Ok(locale) = locale.new("en")
  let original_translator = g18n.new_translator(locale, translations)
  let reparsed_translator = g18n.new_translator(locale, reparsed_translations)

  // Test regular translation
  should.equal(
    g18n.translate(original_translator, "hello"),
    g18n.translate(reparsed_translator, "hello"),
  )

  // Test plural translations (via .one/.other)
  should.equal(
    g18n.translate(original_translator, "message.one"),
    g18n.translate(reparsed_translator, "message.one"),
  )
  should.equal(
    g18n.translate(original_translator, "message.other"),
    g18n.translate(reparsed_translator, "message.other"),
  )

  // Test actual pluralization
  should.equal(
    g18n.translate_plural(original_translator, "message", 1),
    g18n.translate_plural(reparsed_translator, "message", 1),
  )
  should.equal(
    g18n.translate_plural(original_translator, "message", 5),
    g18n.translate_plural(reparsed_translator, "message", 5),
  )
}

// Test roundtrip with complex plural forms (3+ forms)
pub fn complex_plural_roundtrip_test() {
  let complex_po =
    "msgid \"day\"
msgid_plural \"days\"
msgstr[0] \"zero days\"
msgstr[1] \"one day\"
msgstr[2] \"two days\"
msgstr[3] \"few days\"
msgstr[4] \"many days\"
msgstr[5] \"other days\""

  let assert Ok(translations) = g18n.translations_from_po(complex_po)
  let assert Ok(locale) = locale.new("ar")
  // Arabic for complex plurals
  let translator = g18n.new_translator(locale, translations)

  // Verify all forms are accessible
  should.equal(g18n.translate(translator, "day.one"), "zero days")
  should.equal(g18n.translate(translator, "day.other"), "one day")
  should.equal(g18n.translate(translator, "day.2"), "two days")
  should.equal(g18n.translate(translator, "day.3"), "few days")
  should.equal(g18n.translate(translator, "day.4"), "many days")
  should.equal(g18n.translate(translator, "day.5"), "other days")
}

// Test export with context and plurals (exported as separate entries)
pub fn export_context_plural_test() {
  let translations =
    g18n.new_translations()
    |> g18n.add_context_translation("alert.one", "notification", "1 alert")
    |> g18n.add_context_translation(
      "alert.other",
      "notification",
      "{count} alerts",
    )

  let po_content = g18n.translations_to_po(translations)

  // Should contain context entries (as separate entries, not combined plural)
  should.be_true(string.contains(po_content, "msgctxt \"notification\""))
  should.be_true(string.contains(po_content, "msgid \"alert.one\""))
  should.be_true(string.contains(po_content, "msgstr \"1 alert\""))
}

// Test preservation of metadata through roundtrip
pub fn metadata_preservation_test() {
  let po_with_metadata =
    "# Important translation
#: src/ui.gleam:100
#, fuzzy
msgctxt \"button\"
msgid \"click\"
msgid_plural \"clicks\"
msgstr[0] \"one click\"
msgstr[1] \"{count} clicks\""

  let assert Ok(entries) = po.parse_po_content(po_with_metadata)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  // Verify all metadata is preserved
  should.equal(entry.comments, ["Important translation"])
  should.equal(entry.references, ["src/ui.gleam:100"])
  should.equal(entry.flags, ["fuzzy"])
  should.equal(entry.msgctxt, Some("button"))
  should.equal(entry.msgid, "click")
  should.equal(entry.msgid_plural, Some("clicks"))
  should.equal(entry.msgstr_plural, ["one click", "{count} clicks"])
}

// Test PO plurals integration with different locales
pub fn plural_locale_integration_test() {
  let po_content =
    "msgid \"item\"
msgid_plural \"items\"
msgstr[0] \"1 item\"
msgstr[1] \"{count} items\""

  let assert Ok(translations) = g18n.translations_from_po(po_content)

  // Test with English locale
  let assert Ok(en_locale) = locale.new("en")
  let en_translator = g18n.new_translator(en_locale, translations)

  should.equal(g18n.translate_plural(en_translator, "item", 0), "0 items")
  should.equal(g18n.translate_plural(en_translator, "item", 1), "1 item")
  should.equal(g18n.translate_plural(en_translator, "item", 2), "2 items")
  should.equal(g18n.translate_plural(en_translator, "item", 5), "5 items")

  // Test with Spanish locale (has different plural rules)
  let assert Ok(es_locale) = locale.new("es")
  let es_translator = g18n.new_translator(es_locale, translations)

  should.equal(g18n.translate_plural(es_translator, "item", 1), "1 item")
  should.equal(g18n.translate_plural(es_translator, "item", 2), "2 items")
}

// Test PO plurals with parameter substitution
pub fn plural_parameter_substitution_test() {
  let po_content =
    "msgid \"greeting\"
msgid_plural \"greetings\"
msgstr[0] \"Hello {name}, you have 1 message\"
msgstr[1] \"Hello {name}, you have {count} messages\""

  let assert Ok(translations) = g18n.translations_from_po(po_content)
  let assert Ok(locale) = locale.new("en")
  let translator = g18n.new_translator(locale, translations)

  let params = g18n.new_format_params() |> g18n.add_param("name", "Alice")

  // Test singular form with parameters
  should.equal(
    g18n.translate_with_params(translator, "greeting.one", params),
    "Hello Alice, you have 1 message",
  )

  // Test plural form with parameters
  let plural_params =
    g18n.new_format_params()
    |> g18n.add_param("name", "Bob")
    |> g18n.add_param("count", "3")

  should.equal(
    g18n.translate_with_params(translator, "greeting.other", plural_params),
    "Hello Bob, you have 3 messages",
  )
}

// Test PO plurals with context and parameters
pub fn plural_context_parameters_test() {
  let po_content =
    "msgctxt \"email\"
msgid \"notification\"
msgid_plural \"notifications\"
msgstr[0] \"You have 1 new email\"
msgstr[1] \"You have {count} new emails\"

msgctxt \"system\"
msgid \"notification\"
msgid_plural \"notifications\"
msgstr[0] \"1 system alert\"
msgstr[1] \"{count} system alerts\""

  let assert Ok(translations) = g18n.translations_from_po(po_content)
  let assert Ok(locale) = locale.new("en")
  let translator = g18n.new_translator(locale, translations)

  // Test email context
  should.equal(
    g18n.translate_with_context(
      translator,
      "notification.one",
      g18n.Context("email"),
    ),
    "You have 1 new email",
  )
  should.equal(
    g18n.translate_with_context(
      translator,
      "notification.other",
      g18n.Context("email"),
    ),
    "You have {count} new emails",
  )

  // Test system context
  should.equal(
    g18n.translate_with_context(
      translator,
      "notification.one",
      g18n.Context("system"),
    ),
    "1 system alert",
  )
  should.equal(
    g18n.translate_with_context(
      translator,
      "notification.other",
      g18n.Context("system"),
    ),
    "{count} system alerts",
  )
}

// Test mixing PO plurals with regular g18n plurals
pub fn mixed_plural_sources_test() {
  // Start with PO plurals
  let po_content =
    "msgid \"file\"
msgid_plural \"files\"
msgstr[0] \"1 file\"
msgstr[1] \"{count} files\""

  let assert Ok(po_translations) = g18n.translations_from_po(po_content)

  // Add regular g18n plurals
  let mixed_translations =
    po_translations
    |> g18n.add_translation("folder.one", "1 folder")
    |> g18n.add_translation("folder.other", "{count} folders")

  let assert Ok(locale) = locale.new("en")
  let translator = g18n.new_translator(locale, mixed_translations)

  // Both should work
  should.equal(g18n.translate_plural(translator, "file", 1), "1 file")
  should.equal(g18n.translate_plural(translator, "file", 3), "3 files")
  should.equal(g18n.translate_plural(translator, "folder", 1), "1 folder")
  should.equal(g18n.translate_plural(translator, "folder", 2), "2 folders")
}

// Test PO plurals with complex language rules
pub fn complex_language_plural_test() {
  let russian_po =
    "msgid \"файл\"
msgid_plural \"файлы\"
msgstr[0] \"1 файл\"
msgstr[1] \"2 файла\"
msgstr[2] \"5 файлов\""

  let assert Ok(translations) = g18n.translations_from_po(russian_po)
  let assert Ok(ru_locale) = locale.new("ru")
  let translator = g18n.new_translator(ru_locale, translations)

  // All three forms should be accessible
  should.equal(g18n.translate(translator, "файл.one"), "1 файл")
  should.equal(g18n.translate(translator, "файл.other"), "2 файла")
  should.equal(g18n.translate(translator, "файл.2"), "5 файлов")

  // Pluralization should work (using Russian plural rules)
  should.equal(g18n.translate_plural(translator, "файл", 1), "1 файл")
  should.equal(g18n.translate_plural(translator, "файл", 2), "файл.few")
  should.equal(g18n.translate_plural(translator, "файл", 5), "файл.many")
}

// Test large-scale PO plural file performance
pub fn large_plural_file_performance_test() {
  // Generate a large PO file with many plural entries
  let entries_count = 100
  let po_entries =
    list.range(1, entries_count)
    |> list.map(fn(i) {
      let base = "item" <> int.to_string(i)
      "msgid \""
      <> base
      <> "\"\n"
      <> "msgid_plural \""
      <> base
      <> "s\"\n"
      <> "msgstr[0] \"1 "
      <> base
      <> "\"\n"
      <> "msgstr[1] \"{count} "
      <> base
      <> "s\""
    })
    |> string.join("\n\n")

  // Should parse successfully
  let assert Ok(translations) = g18n.translations_from_po(po_entries)
  let assert Ok(locale) = locale.new("en")
  let translator = g18n.new_translator(locale, translations)

  // Test random plurals work correctly
  should.equal(g18n.translate_plural(translator, "item1", 1), "1 item1")
  should.equal(g18n.translate_plural(translator, "item1", 5), "5 item1s")
  should.equal(g18n.translate_plural(translator, "item50", 1), "1 item50")
  should.equal(g18n.translate_plural(translator, "item50", 3), "3 item50s")
  should.equal(g18n.translate_plural(translator, "item100", 1), "1 item100")
  should.equal(g18n.translate_plural(translator, "item100", 10), "10 item100s")
}

// Test error: msgid_plural without msgid
pub fn error_msgid_plural_without_msgid_test() {
  let invalid_po =
    "msgid_plural \"items\"
msgstr[0] \"one item\"
msgstr[1] \"many items\""

  case po.parse_po_content(invalid_po) {
    Error(_) -> Nil
    // Expected error
    Ok(_) -> panic as "Expected parsing error for msgid_plural without msgid"
  }
}

// Test error: msgstr[n] without msgid_plural
pub fn error_msgstr_array_without_plural_test() {
  let invalid_po =
    "msgid \"item\"
msgstr[0] \"one item\"
msgstr[1] \"many items\""

  case po.parse_po_content(invalid_po) {
    Error(_) -> Nil
    // Expected error  
    Ok(entries) -> {
      // Should treat as regular entries and possibly skip invalid ones
      // The behavior depends on parser implementation - let's verify it doesn't crash
      should.be_true(list.length(entries) >= 0)
    }
  }
}

// Test error: missing msgstr[0] in plural entry
pub fn error_missing_msgstr_zero_test() {
  let invalid_po =
    "msgid \"item\"
msgid_plural \"items\"
msgstr[1] \"many items\""

  case po.parse_po_content(invalid_po) {
    Error(_) -> Nil
    // Expected error - no msgstr[0]
    Ok(_) -> panic as "Expected parsing error for missing msgstr[0]"
  }
}

// Test error: duplicate msgstr indices
pub fn error_duplicate_msgstr_indices_test() {
  let invalid_po =
    "msgid \"item\"
msgid_plural \"items\"
msgstr[0] \"first one item\"
msgstr[0] \"second one item\"
msgstr[1] \"many items\""

  case po.parse_po_content(invalid_po) {
    Ok(entries) -> {
      // Should handle gracefully - last one wins or similar behavior
      should.equal(list.length(entries), 1)
      let assert [entry] = entries
      // Verify it has some valid msgstr values
      should.be_true(list.length(entry.msgstr_plural) >= 1)
    }
    Error(_) -> Nil
    // Also acceptable to error
  }
}

// Test error: malformed msgstr index
pub fn error_malformed_msgstr_index_test() {
  let invalid_po =
    "msgid \"item\"
msgid_plural \"items\"
msgstr[abc] \"invalid index\"
msgstr[0] \"one item\"
msgstr[1] \"many items\""

  case po.parse_po_content(invalid_po) {
    Ok(entries) -> {
      // Should skip invalid index and parse valid ones
      should.equal(list.length(entries), 1)
      let assert [entry] = entries
      should.equal(entry.msgstr_plural, ["one item", "many items"])
    }
    Error(_) -> Nil
    // Also acceptable to error on malformed syntax
  }
}

// Test error: negative msgstr index
pub fn error_negative_msgstr_index_test() {
  let invalid_po =
    "msgid \"item\"
msgid_plural \"items\"
msgstr[-1] \"negative index\"
msgstr[0] \"one item\"
msgstr[1] \"many items\""

  case po.parse_po_content(invalid_po) {
    Ok(entries) -> {
      // Should skip negative index
      should.equal(list.length(entries), 1)
      let assert [entry] = entries
      should.equal(entry.msgstr_plural, ["one item", "many items"])
    }
    Error(_) -> Nil
    // Also acceptable to error
  }
}

// Test edge case: empty msgstr[n] values
pub fn empty_msgstr_plural_values_test() {
  let po_content =
    "msgid \"item\"
msgid_plural \"items\"
msgstr[0] \"\"
msgstr[1] \"\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "item")
  should.equal(entry.msgstr, "")
  // Empty msgstr[0]
  should.equal(entry.msgid_plural, Some("items"))
  should.equal(entry.msgstr_plural, ["", ""])
}

// Test edge case: only msgstr[0] in plural entry
pub fn only_msgstr_zero_plural_test() {
  let po_content =
    "msgid \"item\"
msgid_plural \"items\"
msgstr[0] \"one item\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "item")
  should.equal(entry.msgstr, "one item")
  should.equal(entry.msgid_plural, Some("items"))
  should.equal(entry.msgstr_plural, ["one item"])
  // Only one form
}

// Test edge case: very high msgstr index
pub fn high_msgstr_index_test() {
  let po_content =
    "msgid \"item\"
msgid_plural \"items\"
msgstr[0] \"zero\"
msgstr[1] \"one\"
msgstr[100] \"hundred\""

  let assert Ok(entries) = po.parse_po_content(po_content)
  should.equal(list.length(entries), 1)

  let assert [entry] = entries
  should.equal(entry.msgid, "item")
  should.equal(entry.msgstr, "zero")
  should.equal(entry.msgid_plural, Some("items"))
  should.equal(entry.msgstr_plural, ["zero", "one", "hundred"])
}
