# g18n

A comprehensive internationalization library for Gleam with multi-language support.

[![Package Version](https://img.shields.io/hexpm/v/g18n)](https://hex.pm/packages/g18n)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/g18n/)

## Features

- 🌍 **12 Languages Supported** - English, Spanish, Portuguese, French, German, Italian, Russian, Chinese, Japanese, Korean, Arabic, Hindi
- 🔄 **RTL/LTR Support** - Full bidirectional text support for Arabic, Hebrew, Persian and other RTL languages
- 🤝 **Locale Negotiation** - Smart locale matching with Accept-Language header parsing
- 🎯 **Context-Sensitive Translations** - Disambiguate words with multiple meanings (bank@financial vs bank@river)
- 📅 **Advanced Date/Time Formatting** - Full locale-aware date formatting with day-of-week calculation
- 🔢 **Complete Pluralization** - Proper plural rules for ALL 12 languages including Arabic (6 forms) and Russian (complex Slavic)
- 🏷️ **Number & Currency Formatting** - Locale-specific decimal/currency formatting
- 🔤 **Hierarchical Translations** - Efficient trie-based storage with namespace support
- ⏰ **Relative Time** - "2 hours ago", "hace 3 días", "2時間前" in all languages
- ✅ **Translation Validation** - Built-in completeness checking and coverage reports
- 🛠️ **CLI Code Generation** - Auto-generate type-safe modules from JSON files

## Installation

```sh
gleam add g18n
```

## Module Architecture

g18n is organized into two focused modules for simplicity and clarity:

### Core Modules

- **`g18n`** - Translation management, formatting, validation, and code generation
- **`g18n/locale`** - Locale creation, text direction, negotiation, and plural rules

### Usage Pattern

```gleam
import g18n        // Core translation functions
import g18n/locale // Locale utilities
```

Clean, simple module structure that's easy to understand and use.

## Quick Start

```gleam
import g18n
import g18n/locale
import gleam/dict
import gleam/time/calendar

pub fn main() {
  // Create a locale and translator
  let assert Ok(en_locale) = locale.new("en-US")
  let translations = g18n.new_translations()
    |> g18n.add_translation("welcome", "Welcome {name}!")
    |> g18n.add_translation("item.one", "1 item")
    |> g18n.add_translation("item.other", "{count} items")
  let en_translator = g18n.new_translator(en_locale, translations)
  
  // Basic translation with parameters
  let params = g18n.new_format_params() |> g18n.add_param("name", "Alice")
  let greeting = g18n.translate_with_params(en_translator, "welcome", params)
  // "Welcome Alice!"
  
  // Pluralization
  g18n.translate_plural(en_translator, "item", 5) // "5 items"
  
  // Date formatting (12 languages supported)
  let date = calendar.Date(2024, calendar.January, 15)
  g18n.format_date(en_translator, date, g18n.Full) 
  // "Monday, January 15, 2024 GMT"
  
  // Relative time (12 languages)
  g18n.format_relative_time(en_translator, g18n.Hours(2), g18n.Past)
  // "2 hours ago"
  
  // Number formatting
  g18n.format_number(en_translator, 1234.56, g18n.Currency("USD", 2)) // "$1,234.56"
  
  // RTL/LTR Support
  let assert Ok(arabic) = locale.new("ar")
  locale.get_css_direction(arabic)  // "rtl"

  // Context-sensitive translations  
  let context_translations = g18n.new_translations()
    |> g18n.add_context_translation("bank", "financial", "financial institution")
    |> g18n.add_context_translation("bank", "river", "riverbank")
  let context_translator = g18n.new_translator(en_locale, context_translations)
  g18n.translate_with_context(context_translator, "bank", g18n.Context("financial")) 
  // "financial institution"

  // Locale negotiation
  let available_locales = [en_locale]
  let preferred = locale.parse_accept_language("es-MX,es;q=0.9,en;q=0.8")
  locale.negotiate_locale(available_locales, preferred) // Ok(en_locale)
}
```

## Core Functions

```gleam
import g18n
import g18n/locale
import gleam/time/calendar

// Basic setup
let assert Ok(en_locale) = locale.new("en-US")
let translations = g18n.new_translations()
  |> g18n.add_translation("welcome", "Welcome {name}!")
  |> g18n.add_translation("item.one", "1 item")  
  |> g18n.add_translation("item.other", "{count} items")
let en_translator = g18n.new_translator(en_locale, translations)

// Translation with parameters
let params = g18n.new_format_params() |> g18n.add_param("name", "Alice")
g18n.translate_with_params(en_translator, "welcome", params) // "Welcome Alice!"

// Import from nested JSON (industry standard)
let nested_json = "{\"ui\":{\"button\":{\"save\":\"Save\"}}}"
let assert Ok(nested_translations) = g18n.translations_from_nested_json(nested_json)

// Import from flat JSON (g18n optimized)
let flat_json = "{\"ui.button.save\":\"Save\"}"  
let assert Ok(flat_translations) = g18n.translations_from_json(flat_json)

// Pluralization
g18n.translate_plural(en_translator, "item", 5) // "5 items"

// Date formatting (12 languages supported)
let date = calendar.Date(2024, calendar.January, 15)
g18n.format_date(en_translator, date, g18n.Full) // "Monday, January 15, 2024 GMT"

// Relative time (12 languages)
g18n.format_relative_time(en_translator, g18n.Hours(2), g18n.Past) // "2 hours ago"

// Number & currency formatting
g18n.format_number(en_translator, 1234.56, g18n.Currency("USD", 2)) // "$1,234.56"
```

## CLI Code Generation

## JSON Format Support

g18n supports both flat and nested JSON formats for maximum compatibility:

### Nested JSON (Industry Standard)

```json
{
  "ui": {
    "button": {
      "save": "Save",
      "cancel": "Cancel"
    }
  },
  "user": {
    "welcome": "Welcome {name}!",
    "item": {
      "one": "1 item",
      "other": "{count} items"
    }
  }
}
```

### Flat JSON (g18n Optimized)  

```json
{
  "ui.button.save": "Save",
  "ui.button.cancel": "Cancel", 
  "user.welcome": "Welcome {name}!",
  "user.item.one": "1 item",
  "user.item.other": "{count} items"
}
```

Both formats are automatically converted to g18n's efficient trie-based internal storage.

## CLI Code Generation

Place JSON files (either format) in `src/<project>/translations/`:

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

### Generate from Flat JSON (g18n optimized)

```bash
gleam run -m g18n generate
```

### Generate from Nested JSON (industry standard)

```bash
gleam run -m g18n generate_nested
```

Use generated translations:

```gleam
import my_project/translations
import g18n

let assert Ok(en_translator) = translations.en_translator()
let assert Ok(es_translator) = translations.es_translator()

g18n.translate(en_translator, "welcome")  // "Welcome {name}!"
g18n.translate(es_translator, "welcome")  // "¡Bienvenido {name}!"
```

## Language Examples

```gleam
import g18n
import g18n/locale
import gleam/time/calendar

let date = calendar.Date(2024, calendar.January, 15)

// Date formatting examples across languages:
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
