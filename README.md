# g18n

A platform-agnostic internationalization library for Gleam.

[![Package Version](https://img.shields.io/hexpm/v/g18n)](https://hex.pm/packages/g18n)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/g18n/)

## Features

- 🌍 **Locale Management** - Parse and validate locale codes (en, en-US, pt-BR, etc.)
- 🔤 **Hierarchical Translation System** - Trie-based storage for efficient key organization
- 📝 **String Interpolation** - Template strings with parameter substitution
- 🔢 **Advanced Pluralization** - Cardinal, ordinal, and range pluralization support
- 🏷️ **Number Formatting** - Locale-aware decimal, currency, percentage, and compact formatting
- 📅 **Date & Time Formatting** - Comprehensive date/time formatting with relative time support
- ✅ **Translation Validation** - Built-in validation system with coverage reports
- 🗂️ **Namespace Operations** - Efficient prefix-based translation queries
- 📄 **JSON Support** - Load translations from JSON files
- 🛠️ **Advanced CLI Tool** - Generate Gleam modules from multiple locale files
- 🎯 **Platform Agnostic** - Works on both Erlang and JavaScript targets

## Installation

```sh
gleam add g18n
```

## Quick Start

```gleam
import g18n

pub fn main() {
  // Create a locale
  let assert Ok(locale) = g18n.locale("en-US")
  
  // Create hierarchical translations using dot notation
  let translations = g18n.translations()
    |> g18n.add_translation("ui.button.save", "Save")
    |> g18n.add_translation("ui.button.cancel", "Cancel")
    |> g18n.add_translation("user.welcome", "Welcome {name}!")
    |> g18n.add_translation("item.one", "1 item")
    |> g18n.add_translation("item.other", "{count} items")
  
  // Create a translator
  let translator = g18n.translator(locale, translations)
  
  // Basic hierarchical translation
  g18n.translate(translator, "ui.button.save") // "Save"
  
  // Translation with parameters
  let params = g18n.format_params()
    |> g18n.add_param("name", "Alice")
  g18n.translate_with_params(translator, "user.welcome", params) // "Welcome Alice!"
  
  // Pluralization
  g18n.translate_plural(translator, "item", 5) // "{count} items"
  
  // Number formatting
  g18n.format_number(translator, 1234.56, g18n.Currency("USD", 2)) // "$1234.56"
  
  // Date formatting
  let date = g18n.Date(2023, 12, 25)
  g18n.format_date(translator, date, g18n.Medium) // "Dec 25, 2023"
  
  // Namespace operations
  let button_translations = g18n.get_namespace(translator, "ui.button")
  // Returns all UI button translations
}
```

## API Reference

### Locale Functions

```gleam
// Create a locale from string
g18n.locale("en") // Ok(Locale)
g18n.locale("en-US") // Ok(Locale)
g18n.locale("invalid") // Error(LocaleError)

// Locale information
g18n.locale_string(locale) // "en-US"
g18n.locale_language(locale) // "en"
g18n.locale_region(locale) // Some("US")

// Locale comparison
g18n.locales_match_language(en_us, en_gb) // True
g18n.locales_exact_match(en_us, en_gb) // False
```

### Hierarchical Translation Management

```gleam
// Create empty trie-based translations
let translations = g18n.translations()

// Add hierarchical translations using dot notation
let translations = translations
  |> g18n.add_translation("ui.button.save", "Save")
  |> g18n.add_translation("ui.button.cancel", "Cancel")
  |> g18n.add_translation("errors.validation.required", "This field is required")
  |> g18n.add_translation("user.profile.settings", "Profile Settings")

// Load from JSON (automatically converts to trie structure)
let json_string = "{\"ui.button.save\": \"Save\", \"errors.network.timeout\": \"Timeout\"}"
let assert Ok(translations) = g18n.translations_from_json(json_string)

// Namespace operations
g18n.get_namespace(translator, "ui.button")        // All button translations
g18n.get_keys_with_prefix(translations, "errors")  // All error-related keys
```

### Translator

```gleam
// Create translator
let translator = g18n.translator(locale, translations)

// With fallback
let translator = translator
  |> g18n.with_fallback(fallback_locale, fallback_translations)

// Translate
g18n.translate(translator, "key")

// Translate with parameters
let params = g18n.format_params()
  |> g18n.add_param("name", "Alice")
  |> g18n.add_param("count", "5")
g18n.translate_with_params(translator, "welcome", params)
```

### Advanced Pluralization

#### Cardinal Pluralization (Regular Counting)
```gleam
// Set up cardinal plural translations
let translations = g18n.translations()
  |> g18n.add_translation("item.one", "1 item")
  |> g18n.add_translation("item.other", "{count} items")

// Basic pluralization
g18n.translate_cardinal(translator, "item", 1) // "1 item" 
g18n.translate_cardinal(translator, "item", 5) // "{count} items"
```

#### Ordinal Pluralization (Positions/Rankings)
```gleam
// Set up ordinal translations
let translations = g18n.translations()
  |> g18n.add_translation("position.first", "{ordinal} place")
  |> g18n.add_translation("position.second", "{ordinal} place")
  |> g18n.add_translation("position.third", "{ordinal} place")
  |> g18n.add_translation("position.nth", "{ordinal} place")

// Ordinal translation with automatic suffix generation
g18n.translate_ordinal_with_params(translator, "position", 1, params)  // "1st place"
g18n.translate_ordinal_with_params(translator, "position", 22, params) // "22nd place"
```

#### Range Pluralization
```gleam
// Set up range translations
let translations = g18n.translations()
  |> g18n.add_translation("selection.single", "{from} item selected")
  |> g18n.add_translation("selection.range", "{from}-{to} items selected")

// Range translation
g18n.translate_range_with_params(translator, "selection", 1, 1, params)  // "1 item selected"
g18n.translate_range_with_params(translator, "selection", 3, 7, params)  // "3-7 items selected"
```

### Supported Plural Rules

- **English** (`en`): 1 → one, others → other
- **Portuguese** (`pt`): 0 → zero, 1 → one, others → other  
- **Russian** (`ru`): Complex Slavic rules with one/few/many

### Number Formatting

```gleam
// Decimal formatting (locale-aware separators)
g18n.format_number(en_translator, 1234.56, g18n.Decimal(2))     // "1,234.56"
g18n.format_number(pt_translator, 1234.56, g18n.Decimal(2))     // "1.234,56"

// Currency formatting
g18n.format_number(translator, 29.99, g18n.Currency("USD", 2))  // "$29.99"
g18n.format_number(translator, 29.99, g18n.Currency("EUR", 2))  // "€29.99"

// Percentage formatting  
g18n.format_number(translator, 0.75, g18n.Percentage(1))        // "75.0%"

// Compact numbers
g18n.format_number(translator, 1500000.0, g18n.Compact)         // "1.5M"
g18n.format_number(translator, 2500.0, g18n.Compact)            // "2.5K"

// Scientific notation
g18n.format_number(translator, 1234.56, g18n.Scientific(2))     // "1.23E+00"
```

### Date & Time Formatting

```gleam
// Date formatting
let date = g18n.Date(2023, 12, 25)
g18n.format_date(en_translator, date, g18n.Short)    // "12/25/23"
g18n.format_date(pt_translator, date, g18n.Short)    // "25/12/23"
g18n.format_date(translator, date, g18n.Medium)      // "Dec 25, 2023"
g18n.format_date(translator, date, g18n.Custom("YYYY-MM-DD")) // "2023-12-25"

// Time formatting
let time = g18n.Time(14, 30, 45)
g18n.format_time(en_translator, time, g18n.Short)    // "2:30 PM"
g18n.format_time(pt_translator, time, g18n.Short)    // "14:30"

// DateTime formatting
let datetime = g18n.DateTime(2023, 12, 25, 14, 30, 45)
g18n.format_datetime(translator, datetime, g18n.Medium) // "Dec 25, 2023 2:30:45 PM"

// Relative time formatting
g18n.format_relative_time(en_translator, g18n.Hours(2), True)   // "2 hours ago"
g18n.format_relative_time(pt_translator, g18n.Days(3), False)   // "em 3 dias"
g18n.format_relative_time(es_translator, g18n.Minutes(30), True) // "hace 30 minutos"
```

### Translation Validation

```gleam
// Validate translations between locales
let report = g18n.validate_translations(en_translations, pt_translations, "pt")

// Check coverage
let coverage = g18n.get_translation_coverage(en_translations, pt_translations) // 0.85 (85%)

// Find unused translations
let unused = g18n.find_unused_translations(translations, ["ui.button.save", "user.welcome"])

// Export validation report
let report_text = g18n.export_validation_report(report)
// Generates detailed report with errors, warnings, and coverage statistics

// Validate specific translation parameters
let errors = g18n.validate_translation_parameters(
  translations, 
  "user.welcome", 
  ["name", "count"], 
  "en"
)
```

## CLI Code Generation

The CLI automatically discovers locale files and generates a unified translation module:

### Setup Your Translation Files

Create locale-specific JSON files in `src/<project>/translations/`:

```
src/my_project/translations/
├── en.json
├── es.json  
├── pt.json
└── fr.json
```

**en.json:**
```json
{
  "ui.button.save": "Save",
  "ui.button.cancel": "Cancel",
  "user.welcome": "Welcome {name}!",
  "item.one": "1 item",
  "item.other": "{count} items",
  "errors.validation.required": "This field is required"
}
```

**es.json:**
```json
{
  "ui.button.save": "Guardar",
  "ui.button.cancel": "Cancelar", 
  "user.welcome": "¡Bienvenido {name}!",
  "item.one": "1 artículo",
  "item.other": "{count} artículos",
  "errors.validation.required": "Este campo es obligatorio"
}
```

### Generate Translation Module

Run the generator:

```bash
gleam run generate
```

This creates a single `src/<project>/translations.gleam` file:

```gleam
import g18n

// English translations
pub fn en_translations() -> g18n.Translations {
  g18n.translations()
  |> g18n.add_translation("ui.button.save", "Save")
  |> g18n.add_translation("ui.button.cancel", "Cancel")
  |> g18n.add_translation("user.welcome", "Welcome {name}!")
  |> g18n.add_translation("item.one", "1 item")
  |> g18n.add_translation("item.other", "{count} items")
}

pub fn en_locale() -> Result(g18n.Locale, g18n.LocaleError) {
  g18n.locale("en")
}

pub fn en_translator() -> Result(g18n.Translator, g18n.LocaleError) {
  case en_locale() {
    Ok(loc) -> Ok(g18n.translator(loc, en_translations()))
    Error(err) -> Error(err)
  }
}

// Spanish translations
pub fn es_translations() -> g18n.Translations {
  g18n.translations()
  |> g18n.add_translation("ui.button.save", "Guardar")
  |> g18n.add_translation("ui.button.cancel", "Cancelar")
  |> g18n.add_translation("user.welcome", "¡Bienvenido {name}!")
  |> g18n.add_translation("item.one", "1 artículo")
  |> g18n.add_translation("item.other", "{count} artículos")
}

pub fn es_locale() -> Result(g18n.Locale, g18n.LocaleError) {
  g18n.locale("es")
}

pub fn es_translator() -> Result(g18n.Translator, g18n.LocaleError) {
  case es_locale() {
    Ok(loc) -> Ok(g18n.translator(loc, es_translations()))
    Error(err) -> Error(err)
  }
}

// Utility function
pub fn available_locales() -> List(String) {
  ["en", "es", "pt", "fr"]
}
```

### Usage with Generated Translations

```gleam
import my_project/translations

pub fn main() {
  // Use locale-specific translators
  let assert Ok(en_translator) = translations.en_translator()
  let assert Ok(es_translator) = translations.es_translator()
  
  // Basic translations
  g18n.translate(en_translator, "ui.button.save")  // "Save"
  g18n.translate(es_translator, "ui.button.save")  // "Guardar"
  
  // With parameters
  let params = g18n.format_params() |> g18n.add_param("name", "Maria")
  g18n.translate_with_params(en_translator, "user.welcome", params) // "Welcome Maria!"
  g18n.translate_with_params(es_translator, "user.welcome", params) // "¡Bienvenido Maria!"
  
  // Namespace operations work with generated translations
  let button_translations = g18n.get_namespace(en_translator, "ui.button")
  // Returns [#("ui.button.save", "Save"), #("ui.button.cancel", "Cancel")]
  
  // Validation between locales  
  let en_trans = translations.en_translations()
  let es_trans = translations.es_translations()
  let report = g18n.validate_translations(en_trans, es_trans, "es")
  
  // Get available locales
  let locales = translations.available_locales() // ["en", "es", "pt", "fr"]
}
```

## Key Features Explained

### Hierarchical Keys & Namespaces

The trie-based storage system efficiently organizes translations using dot notation:

```gleam
// Organize translations by feature/component
g18n.add_translation("ui.button.save", "Save")
g18n.add_translation("ui.button.cancel", "Cancel")
g18n.add_translation("ui.dialog.confirm", "Confirm")
g18n.add_translation("errors.network.timeout", "Network timeout")
g18n.add_translation("errors.validation.email", "Invalid email")

// Query entire namespaces efficiently
let all_buttons = g18n.get_namespace(translator, "ui.button")
let all_errors = g18n.get_namespace(translator, "errors")
let all_ui = g18n.get_namespace(translator, "ui")
```

### Fallback System

Set up translation fallbacks for graceful degradation:

```gleam
let assert Ok(en_locale) = g18n.locale("en")
let assert Ok(en_us_locale) = g18n.locale("en-US")

let en_translations = g18n.translations()
  |> g18n.add_translation("ui.button.save", "Save")
  |> g18n.add_translation("user.greeting", "Hello")

let en_us_translations = g18n.translations()
  |> g18n.add_translation("user.greeting", "Hey there!")

let translator = g18n.translator(en_us_locale, en_us_translations)
  |> g18n.with_fallback(en_locale, en_translations)

g18n.translate(translator, "user.greeting")    // "Hey there!" (from en-US)
g18n.translate(translator, "ui.button.save")   // "Save" (from en fallback)
g18n.translate(translator, "missing.key")      // "missing.key" (key as fallback)
```

### Production Workflow

1. **Development**: Create/edit JSON translation files
2. **Code Generation**: Run `gleam run generate` to create type-safe Gleam modules  
3. **Validation**: Use validation functions to ensure translation completeness
4. **Integration**: Import generated modules and use locale-specific translators

## Platform Support

This library is designed to be platform-agnostic and works on:

- **Erlang target** - Server-side applications
- **JavaScript target** - Browser and Node.js applications

All functionality uses only Gleam standard library and carefully selected dependencies.

## Architecture

### Trie-Based Storage
- **Memory Efficient**: Common prefixes stored once (ui.*, errors.*, user.*)
- **Fast Lookups**: O(k) complexity where k is key depth
- **Namespace Support**: Efficient prefix-based queries
- **Hierarchical Organization**: Natural grouping of related translations

### Type Safety
- **Compile-Time Validation**: Generated modules provide type-safe translation access
- **Parameter Validation**: Built-in checking for missing/unused parameters
- **Locale Validation**: Strong typing for locale codes and formats
- **Error Handling**: Graceful fallbacks and detailed error reporting

### Performance
- **Platform Optimized**: Works efficiently on both Erlang and JavaScript targets
- **Lazy Evaluation**: Translations loaded only when needed
- **Memory Conscious**: Trie structure minimizes memory usage for large translation sets
- **Fast Namespace Queries**: Efficient retrieval of translation groups

## Development

```sh
gleam run         # Run the project
gleam test        # Run the tests (14 comprehensive tests)
gleam run generate # Generate translations from JSON files
gleam run help    # Show CLI usage information
```

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT
