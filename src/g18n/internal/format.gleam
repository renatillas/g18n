import gleam/dict.{type Dict}
import gleam/string

pub type FormatParams =
  Dict(String, String)

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
pub fn format_string(template: String, params: FormatParams) -> String {
  dict.fold(params, template, fn(acc, key, value) {
    string.replace(acc, "{" <> key <> "}", value)
  })
}
