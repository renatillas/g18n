# g18n

A comprehensive internationalization library for Gleam with multi-language support.

[![Package Version](https://img.shields.io/hexpm/v/g18n)](https://hex.pm/packages/g18n)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/g18n/)

## Features

- 🌍 **12 Languages Supported** - English, Spanish, Portuguese, French, German, Italian, Russian, Chinese, Japanese, Korean, Arabic, Hindi
- 📅 **Advanced Date/Time Formatting** - Full locale-aware date formatting with day-of-week calculation
- 🔢 **Smart Pluralization** - Proper plural rules for complex languages (Russian, Arabic) 
- 🏷️ **Number & Currency Formatting** - Locale-specific decimal/currency formatting
- 🔤 **Hierarchical Translations** - Efficient trie-based storage with namespace support
- ⏰ **Relative Time** - "2 hours ago", "hace 3 días", "2時間前" in all languages
- ✅ **Translation Validation** - Built-in completeness checking and coverage reports
- 🛠️ **CLI Code Generation** - Auto-generate type-safe modules from JSON files

## Installation

```sh
gleam add g18n
```

## Quick Start

```gleam
import g18n
import gleam/time/calendar

pub fn main() {
  // Create a locale and translator
  let assert Ok(locale) = g18n.locale("en-US")
  let translations = g18n.translations()
    |> g18n.add_translation("welcome", "Welcome {name}!")
    |> g18n.add_translation("item.one", "1 item")
    |> g18n.add_translation("item.other", "{count} items")
  let translator = g18n.translator(locale, translations)
  
  // Basic translation with parameters
  let params = g18n.format_params() |> g18n.add_param("name", "Alice")
  g18n.translate_with_params(translator, "welcome", params) // "Welcome Alice!"
  
  // Pluralization
  g18n.translate_plural(translator, "item", 5) // "{count} items"
  
  // Date formatting (12 languages supported)
  let date = calendar.Date(2024, calendar.January, 15)
  g18n.format_date(translator, date, g18n.Full) 
  // "Monday, January 15, 2024 GMT"
  
  // Relative time (12 languages)
  g18n.format_relative_time(translator, g18n.Hours(2), g18n.Past)
  // "2 hours ago"
  
  // Number formatting
  g18n.format_number(translator, 1234.56, g18n.Currency("USD", 2)) // "$1234.56"
}
```

## Core Functions

```gleam
// Basic setup
let assert Ok(locale) = g18n.locale("en-US")
let translations = g18n.translations()
  |> g18n.add_translation("welcome", "Welcome {name}!")
  |> g18n.add_translation("item.one", "1 item")  
  |> g18n.add_translation("item.other", "{count} items")
let translator = g18n.translator(locale, translations)

// Translation with parameters
let params = g18n.format_params() |> g18n.add_param("name", "Alice")
g18n.translate_with_params(translator, "welcome", params) // "Welcome Alice!"

// Pluralization
g18n.translate_plural(translator, "item", 5) // "{count} items"

// Date formatting (12 languages supported)
let date = calendar.Date(2024, calendar.January, 15) 
g18n.format_date(translator, date, g18n.Full) // "Monday, January 15, 2024 GMT"

// Relative time (12 languages)
g18n.format_relative_time(translator, g18n.Hours(2), g18n.Past) // "2 hours ago"

// Number & currency formatting
g18n.format_number(translator, 1234.56, g18n.Currency("USD", 2)) // "$1234.56"
```

## CLI Code Generation

Place JSON files in `src/<project>/translations/`:

**en.json:**
```json
{
  "welcome": "Welcome {name}!",
  "item.one": "1 item",
  "item.other": "{count} items"
}
```

**es.json:**
```json
{
  "welcome": "¡Bienvenido {name}!",
  "item.one": "1 artículo", 
  "item.other": "{count} artículos"
}
```

Generate code:
```bash
gleam run generate
```

Use generated translations:
```gleam
import my_project/translations

let assert Ok(en_translator) = translations.en_translator()
let assert Ok(es_translator) = translations.es_translator()

g18n.translate(en_translator, "welcome")  // "Welcome {name}!"
g18n.translate(es_translator, "welcome")  // "¡Bienvenido {name}!"
```

## Language Examples

```gleam
let date = calendar.Date(2024, calendar.January, 15)

// English: "Monday, January 15, 2024 GMT"
// Spanish: "lunes, 15 de enero de 2024 GMT" 
// Chinese: "2024年一月15日星期一 GMT"
// Russian: "понедельник, 15 январь 2024 г. GMT"
// Arabic: "الإثنين، 15 يناير 2024 GMT"

g18n.format_relative_time(translator, g18n.Hours(2), g18n.Past)
// English: "2 hours ago"
// Spanish: "hace 2 horas"  
// Chinese: "2小时前"
// Russian: "2 часа назад"
```

## Validation & CLI

- **Translation validation**: Check completeness across locales
- **Coverage reports**: Track translation progress  
- **JSON → Gleam**: Auto-generate type-safe translation modules
- **Namespace queries**: Efficiently find related translations

## Development

```sh
gleam add g18n        # Install
gleam test           # Run tests (20 comprehensive tests)  
gleam run generate   # Generate translation modules
```

See function documentation for detailed API examples and usage patterns.

## License

MIT
