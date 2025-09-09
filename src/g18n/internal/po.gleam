import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// A PO file entry representing a translation pair
pub type PoEntry {
  PoEntry(
    msgid: String,
    msgstr: String,
    msgctxt: Option(String),
    comments: List(String),
    references: List(String),
    flags: List(String),
  )
}

/// Parse result for PO file operations
pub type ParseResult(a) =
  Result(a, ParseError)

/// Errors that can occur during PO file parsing
pub type ParseError {
  InvalidFormat(String)
  UnexpectedEof
  InvalidEscapeSequence(String)
  MissingMsgid
  MissingMsgstr
}

/// Parse a PO file content string into a list of entries
pub fn parse_po_content(content: String) -> ParseResult(List(PoEntry)) {
  content
  |> string.trim
  |> string.split("\n")
  |> parse_lines([])
}

/// Internal function to parse lines into PO entries
fn parse_lines(
  lines: List(String),
  acc: List(PoEntry),
) -> ParseResult(List(PoEntry)) {
  case lines {
    [] -> Ok(list.reverse(acc))
    _ -> {
      // Skip any remaining empty lines or whitespace-only lines
      let non_empty_lines =
        list.drop_while(lines, fn(line) { string.trim(line) == "" })
      case non_empty_lines {
        [] -> Ok(list.reverse(acc))
        _ -> {
          case parse_single_entry(non_empty_lines) {
            Ok(#(entry, remaining_lines)) ->
              parse_lines(remaining_lines, [entry, ..acc])
            Error(MissingMsgid) -> {
              // Skip lines that are only comments and try again, but ensure we make progress
              let next_lines =
                list.drop_while(non_empty_lines, fn(line) {
                  let trimmed = string.trim(line)
                  trimmed == "" || string.starts_with(trimmed, "#")
                })
              case next_lines {
                [] -> Ok(list.reverse(acc))
                // No more content, we're done
                _ -> {
                  // If we haven't made progress, skip at least one line to avoid infinite loop
                  let final_lines = case
                    list.length(next_lines) == list.length(non_empty_lines)
                  {
                    True ->
                      case next_lines {
                        [_, ..rest] -> rest
                        [] -> []
                      }
                    False -> next_lines
                  }
                  parse_lines(final_lines, acc)
                }
              }
            }
            Error(err) -> Error(err)
          }
        }
      }
    }
  }
}

/// Parse a single PO entry from the beginning of the lines list
fn parse_single_entry(
  lines: List(String),
) -> ParseResult(#(PoEntry, List(String))) {
  let #(comments, references, flags, remaining) =
    extract_comments_and_flags(lines, [], [], [])

  case parse_entry_content(remaining) {
    Ok(#(msgctxt, msgid, msgstr, leftover_lines)) -> {
      let entry =
        PoEntry(
          msgid: msgid,
          msgstr: msgstr,
          msgctxt: msgctxt,
          comments: list.reverse(comments),
          references: list.reverse(references),
          flags: list.reverse(flags),
        )
      Ok(#(entry, leftover_lines))
    }
    Error(err) -> Error(err)
  }
}

/// Extract comments, references, and flags from the beginning of lines
fn extract_comments_and_flags(
  lines: List(String),
  comments: List(String),
  references: List(String),
  flags: List(String),
) -> #(List(String), List(String), List(String), List(String)) {
  case lines {
    [] -> #(comments, references, flags, [])
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case trimmed {
        "" -> extract_comments_and_flags(rest, comments, references, flags)
        _ -> {
          case string.starts_with(trimmed, "#:") {
            True -> {
              let ref = string.drop_start(trimmed, 2) |> string.trim
              extract_comments_and_flags(
                rest,
                comments,
                [ref, ..references],
                flags,
              )
            }
            False ->
              case string.starts_with(trimmed, "#,") {
                True -> {
                  let flag = string.drop_start(trimmed, 2) |> string.trim
                  extract_comments_and_flags(rest, comments, references, [
                    flag,
                    ..flags
                  ])
                }
                False ->
                  case string.starts_with(trimmed, "#") {
                    True -> {
                      let comment = string.drop_start(trimmed, 1) |> string.trim
                      extract_comments_and_flags(
                        rest,
                        [comment, ..comments],
                        references,
                        flags,
                      )
                    }
                    False -> #(comments, references, flags, lines)
                  }
              }
          }
        }
      }
    }
  }
}

/// Parse the main content of a PO entry (msgctxt, msgid, msgstr)
fn parse_entry_content(
  lines: List(String),
) -> ParseResult(#(Option(String), String, String, List(String))) {
  // If we have no lines left, there's no entry to parse
  case lines {
    [] -> Error(MissingMsgid)
    _ -> {
      case extract_message_field(lines, "msgctxt") {
        Ok(#(Some(msgctxt), remaining1)) ->
          case extract_message_field(remaining1, "msgid") {
            Ok(#(Some(msgid), remaining2)) ->
              case extract_message_field(remaining2, "msgstr") {
                Ok(#(Some(msgstr), remaining3)) ->
                  Ok(#(Some(msgctxt), msgid, msgstr, remaining3))
                Ok(#(None, _)) -> Error(MissingMsgstr)
                Error(err) -> Error(err)
              }
            Ok(#(None, _)) -> Error(MissingMsgid)
            Error(err) -> Error(err)
          }
        Ok(#(None, remaining1)) ->
          case extract_message_field(remaining1, "msgid") {
            Ok(#(Some(msgid), remaining2)) ->
              case extract_message_field(remaining2, "msgstr") {
                Ok(#(Some(msgstr), remaining3)) ->
                  Ok(#(None, msgid, msgstr, remaining3))
                Ok(#(None, _)) -> Error(MissingMsgstr)
                Error(err) -> Error(err)
              }
            Ok(#(None, _)) -> Error(MissingMsgid)
            Error(err) -> Error(err)
          }
        Error(err) -> Error(err)
      }
    }
  }
}

/// Extract a message field (msgid, msgstr, msgctxt) and its value
fn extract_message_field(
  lines: List(String),
  field_name: String,
) -> ParseResult(#(Option(String), List(String))) {
  case lines {
    [] -> Ok(#(None, []))
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case string.starts_with(trimmed, field_name <> " ") {
        True -> {
          let value_part =
            string.drop_start(trimmed, string.length(field_name) + 1)
          case parse_quoted_string(value_part) {
            Ok(initial_value) -> {
              let #(full_value, remaining_lines) =
                collect_multiline_string(initial_value, rest)
              Ok(#(Some(full_value), remaining_lines))
            }
            Error(err) -> Error(err)
          }
        }
        False -> Ok(#(None, lines))
      }
    }
  }
}

/// Collect multiline string continuation
fn collect_multiline_string(
  initial: String,
  lines: List(String),
) -> #(String, List(String)) {
  case lines {
    [] -> #(initial, [])
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case
        string.starts_with(trimmed, "\"") && string.ends_with(trimmed, "\"")
      {
        True -> {
          case parse_quoted_string(trimmed) {
            Ok(continuation) -> {
              let combined = initial <> continuation
              collect_multiline_string(combined, rest)
            }
            Error(_) -> #(initial, lines)
          }
        }
        False -> #(initial, lines)
      }
    }
  }
}

/// Parse a quoted string, handling escape sequences
fn parse_quoted_string(input: String) -> ParseResult(String) {
  let trimmed = string.trim(input)
  case string.starts_with(trimmed, "\"") && string.ends_with(trimmed, "\"") {
    True -> {
      let content =
        trimmed
        |> string.drop_start(1)
        |> string.drop_end(1)
      unescape_string(content)
    }
    False -> Error(InvalidFormat("Expected quoted string, got: " <> input))
  }
}

/// Unescape C-style escape sequences in strings
fn unescape_string(input: String) -> ParseResult(String) {
  unescape_helper(string.to_graphemes(input), [])
}

fn unescape_helper(
  chars: List(String),
  acc: List(String),
) -> ParseResult(String) {
  case chars {
    [] -> Ok(string.join(list.reverse(acc), ""))
    ["\\", "n", ..rest] -> unescape_helper(rest, ["\n", ..acc])
    ["\\", "t", ..rest] -> unescape_helper(rest, ["\t", ..acc])
    ["\\", "r", ..rest] -> unescape_helper(rest, ["\r", ..acc])
    ["\\", "\"", ..rest] -> unescape_helper(rest, ["\"", ..acc])
    ["\\", "\\", ..rest] -> unescape_helper(rest, ["\\", ..acc])
    ["\\", char, ..] -> Error(InvalidEscapeSequence("\\" <> char))
    [char, ..rest] -> unescape_helper(rest, [char, ..acc])
  }
}

/// Convert PO entries to a flat dictionary suitable for g18n
pub fn entries_to_translations(entries: List(PoEntry)) -> Dict(String, String) {
  entries
  |> list.fold(dict.new(), fn(acc, entry) {
    case entry.msgctxt {
      Some(context) -> {
        let key = entry.msgid <> "@" <> context
        dict.insert(acc, key, entry.msgstr)
      }
      None -> dict.insert(acc, entry.msgid, entry.msgstr)
    }
  })
}
