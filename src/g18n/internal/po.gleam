import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// A PO file entry representing a translation pair
pub type PoEntry {
  PoEntry(
    msgid: String,
    msgstr: String,
    msgid_plural: Option(String),
    msgstr_plural: List(String),
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
              // Check for specific fatal error patterns that indicate malformed PO syntax
              // msgid_plural without msgid should be a fatal error
              let has_fatal_syntax =
                list.any(non_empty_lines, fn(line) {
                  let trimmed = string.trim(line)
                  string.starts_with(trimmed, "msgid_plural ")
                })

              case has_fatal_syntax {
                True -> Error(MissingMsgid)
                // Fatal error - msgid_plural without msgid
                False -> {
                  // Skip lines that are only comments or orphaned msgstr and try again
                  let next_lines =
                    list.drop_while(non_empty_lines, fn(line) {
                      let trimmed = string.trim(line)
                      trimmed == ""
                      || string.starts_with(trimmed, "#")
                      || string.starts_with(trimmed, "msgstr")
                      || string.starts_with(trimmed, "msgstr[")
                    })
                  case next_lines {
                    [] -> Ok(list.reverse(acc))
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
    Ok(#(msgctxt, msgid, msgstr, msgid_plural, msgstr_plural, leftover_lines)) -> {
      let entry =
        PoEntry(
          msgid: msgid,
          msgstr: msgstr,
          msgid_plural: msgid_plural,
          msgstr_plural: msgstr_plural,
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

/// Parse the main content of a PO entry (msgctxt, msgid, msgstr, msgid_plural, msgstr[n])
fn parse_entry_content(
  lines: List(String),
) -> ParseResult(
  #(Option(String), String, String, Option(String), List(String), List(String)),
) {
  // If we have no lines left, there's no entry to parse
  case lines {
    [] -> Error(MissingMsgid)
    _ -> {
      // Parse context first (optional)
      case extract_message_field(lines, "msgctxt") {
        Ok(#(msgctxt, remaining1)) -> {
          case parse_message_content(remaining1) {
            Ok(#(msgid, msgstr, msgid_plural, msgstr_plural, remaining_final)) ->
              Ok(#(
                msgctxt,
                msgid,
                msgstr,
                msgid_plural,
                msgstr_plural,
                remaining_final,
              ))
            Error(err) -> Error(err)
          }
        }
        Error(err) -> Error(err)
      }
    }
  }
}

/// Parse message content (msgid, msgstr, optional msgid_plural and msgstr[n])
fn parse_message_content(
  lines: List(String),
) -> ParseResult(#(String, String, Option(String), List(String), List(String))) {
  // Parse required msgid
  case extract_message_field(lines, "msgid") {
    Ok(#(Some(msgid), remaining1)) -> {
      // Check if this is a plural entry by looking for msgid_plural
      case extract_message_field(remaining1, "msgid_plural") {
        Ok(#(Some(msgid_plural), remaining2)) -> {
          // This is a plural entry - parse msgstr[n] forms
          case extract_plural_msgstr(remaining2, 0, []) {
            Ok(#(msgstr_plural, remaining3)) -> {
              // For plural entries, msgstr is msgstr[0] (first form)
              case list.first(msgstr_plural) {
                Ok(first_msgstr) ->
                  Ok(#(
                    msgid,
                    first_msgstr,
                    Some(msgid_plural),
                    msgstr_plural,
                    remaining3,
                  ))
                Error(Nil) -> Error(MissingMsgstr)
              }
            }
            Error(err) -> Error(err)
          }
        }
        Ok(#(None, remaining2)) -> {
          // Not a plural entry - parse single msgstr
          case extract_message_field(remaining2, "msgstr") {
            Ok(#(Some(msgstr), remaining3)) ->
              Ok(#(msgid, msgstr, None, [], remaining3))
            Ok(#(None, _)) -> Error(MissingMsgstr)
            Error(err) -> Error(err)
          }
        }
        Error(err) -> Error(err)
      }
    }
    Ok(#(None, _)) -> Error(MissingMsgid)
    Error(err) -> Error(err)
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

/// Extract all msgstr[n] forms for plural entries
fn extract_plural_msgstr(
  lines: List(String),
  _index: Int,
  _acc: List(#(Int, String)),
) -> ParseResult(#(List(String), List(String))) {
  extract_all_msgstr_indices(lines, [], [])
}

/// Scan all lines for msgstr[n] patterns and collect them
fn extract_all_msgstr_indices(
  lines: List(String),
  remaining_lines: List(String),
  acc: List(#(Int, String)),
) -> ParseResult(#(List(String), List(String))) {
  case lines {
    [] -> finalize_plural_msgstr(list.reverse(remaining_lines), acc)
    [line, ..rest] -> {
      case try_parse_msgstr_index(line) {
        Ok(index) -> {
          // Found msgstr[n], extract its value
          case
            extract_message_field(
              [line, ..rest],
              "msgstr[" <> int.to_string(index) <> "]",
            )
          {
            Ok(#(Some(msgstr), after_msgstr)) -> {
              extract_all_msgstr_indices(after_msgstr, remaining_lines, [
                #(index, msgstr),
                ..acc
              ])
            }
            Ok(#(None, _)) ->
              extract_all_msgstr_indices(rest, [line, ..remaining_lines], acc)
            Error(err) -> Error(err)
          }
        }
        Error(_) -> {
          // Not a msgstr[n] line - check if this starts a new entry
          let trimmed = string.trim(line)
          case
            string.starts_with(trimmed, "msgid ")
            || string.starts_with(trimmed, "msgctxt ")
          {
            True -> {
              // This starts a new entry - stop processing and return all remaining lines
              finalize_plural_msgstr([line, ..rest], acc)
            }
            False -> {
              // Not a new entry (comment, empty line, etc.) - add to remaining and continue
              extract_all_msgstr_indices(rest, [line, ..remaining_lines], acc)
            }
          }
        }
      }
    }
  }
}

/// Try to parse msgstr[n] index from a line
fn try_parse_msgstr_index(line: String) -> Result(Int, Nil) {
  let trimmed = string.trim(line)
  case string.starts_with(trimmed, "msgstr[") {
    True -> {
      case string.split_once(trimmed, "[") {
        Ok(#(_, after_bracket)) -> {
          case string.split_once(after_bracket, "]") {
            Ok(#(index_str, _)) -> {
              case int.parse(index_str) {
                Ok(index) -> {
                  // Only accept non-negative indices
                  case index >= 0 {
                    True -> Ok(index)
                    False -> Error(Nil)
                  }
                }
                Error(_) -> Error(Nil)
              }
            }
            Error(_) -> Error(Nil)
          }
        }
        Error(_) -> Error(Nil)
      }
    }
    False -> Error(Nil)
  }
}

/// Finalize plural msgstr collection
fn finalize_plural_msgstr(
  remaining_lines: List(String),
  acc: List(#(Int, String)),
) -> ParseResult(#(List(String), List(String))) {
  case acc {
    [] -> Error(MissingMsgstr)
    // Need at least one msgstr[n]
    _ -> {
      // Sort by index and extract values
      let sorted_entries =
        acc
        |> list.sort(fn(a, b) { int.compare(a.0, b.0) })

      // Validate that msgstr[0] is present (required for plural entries)
      case list.first(sorted_entries) {
        Ok(#(0, _)) -> {
          let values = list.map(sorted_entries, fn(entry) { entry.1 })
          Ok(#(values, remaining_lines))
        }
        Ok(#(first_index, _)) ->
          Error(InvalidFormat(
            "Plural entry must start with msgstr[0], found msgstr["
            <> int.to_string(first_index)
            <> "]",
          ))
        Error(Nil) -> Error(MissingMsgstr)
      }
    }
  }
}

/// Convert PO entries to a flat dictionary suitable for g18n
/// Plural forms are converted to g18n's .one/.other suffix format
pub fn entries_to_translations(entries: List(PoEntry)) -> Dict(String, String) {
  entries
  |> list.fold(dict.new(), fn(acc, entry) {
    case entry.msgstr_plural {
      [] -> {
        // Regular non-plural entry
        let key = case entry.msgctxt {
          Some(context) -> entry.msgid <> "@" <> context
          None -> entry.msgid
        }
        dict.insert(acc, key, entry.msgstr)
      }
      plural_forms -> {
        // Plural entry - convert to g18n format
        // msgstr[0] typically maps to "one" form
        // msgstr[1] typically maps to "other" form
        let acc_with_one = case list.first(plural_forms) {
          Ok(one_form) -> {
            let key = case entry.msgctxt {
              Some(context) -> entry.msgid <> ".one@" <> context
              None -> entry.msgid <> ".one"
            }
            dict.insert(acc, key, one_form)
          }
          Error(Nil) -> acc
        }
        let acc_with_other = case list.drop(plural_forms, 1) |> list.first {
          Ok(other_form) -> {
            let key = case entry.msgctxt {
              Some(context) -> entry.msgid <> ".other@" <> context
              None -> entry.msgid <> ".other"
            }
            dict.insert(acc_with_one, key, other_form)
          }
          Error(Nil) -> acc_with_one
        }
        // For languages with more than 2 plural forms, we'll add them as .2, .3, etc.
        list.index_fold(
          list.drop(plural_forms, 2),
          acc_with_other,
          fn(dict_acc, form, index) {
            let suffix = "." <> int.to_string(index + 2)
            let key = case entry.msgctxt {
              Some(context) -> entry.msgid <> suffix <> "@" <> context
              None -> entry.msgid <> suffix
            }
            dict.insert(dict_acc, key, form)
          },
        )
      }
    }
  })
}
