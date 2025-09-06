# g18n Syntax Guide

This comprehensive guide covers all syntax formats and conventions used in the g18n internationalization library for Gleam.

## Table of Contents

1. [Translation Key Syntax](#translation-key-syntax)
2. [Parameter Substitution](#parameter-substitution)
3. [Pluralization Syntax](#pluralization-syntax)
4. [Context-Sensitive Translations](#context-sensitive-translations)
5. [JSON Format Syntax](#json-format-syntax)
6. [Date & Time Format Syntax](#date--time-format-syntax)
7. [Number Format Syntax](#number-format-syntax)
8. [Locale Code Syntax](#locale-code-syntax)
9. [CLI Usage Syntax](#cli-usage-syntax)
10. [Advanced Patterns](#advanced-patterns)

---

## Translation Key Syntax

### Hierarchical Keys (Dot Notation)

g18n uses **dot notation** to organize translations hierarchically for better maintainability and namespace organization.

```gleam
// Basic key structure
"key"                    // Simple key
"category.key"          // One level nesting
"category.subcategory.key"  // Multiple levels

// Real-world examples
"ui.button.save"        // UI components
"ui.button.cancel"
"ui.dialog.confirm"
"errors.validation.required"
"errors.network.timeout"
"user.profile.settings"
"auth.login.email"
"auth.login.password"
```

### Key Naming Conventions

```gleam
// ✅ Good naming patterns
"user.name"             // Clear, descriptive
"ui.button.save"        // Organized by feature
"errors.validation.email"  // Grouped by type
"dashboard.stats.total"  // Logical hierarchy

// ❌ Poor naming patterns  
"btn_save"              // Non-hierarchical
"user_name_field_label" // Too specific
"error1"                // Non-descriptive
"ui_dashboard_user_profile_settings"  // Too deep
```

### Reserved Characters

```gleam
// Reserved characters in keys
"."  // Hierarchy separator - DO NOT use in key names
"@"  // Context separator - DO NOT use except for contexts
"{}" // Parameter delimiters - DO NOT use in key names

// ✅ Valid keys
"ui.button.save"
"user.email@field" 
"welcome.message"

// ❌ Invalid keys  
"ui.button.sa.ve"      // Extra dots confuse hierarchy
"user@email@field"     // Multiple @ symbols
"welcome{message}"     // Braces reserved for parameters
```

---

## Parameter Substitution

### Basic Parameter Syntax

Parameters use **curly brace syntax** `{param}` for substitution.

```gleam
// Basic parameter templates
"Welcome {name}!"                    // Single parameter
"Hello {firstName} {lastName}!"      // Multiple parameters
"You have {count} new messages"      // Numeric parameters

// Parameter naming conventions
"Welcome {user_name}!"               // Snake_case
"Welcome {userName}!"                // camelCase
"Welcome {UserName}!"                // PascalCase (less common)
```

### Parameter Examples

```gleam
// Setting up parameters in code
let params = g18n.format_params()
  |> g18n.add_param("name", "Alice")
  |> g18n.add_param("count", "5")
  |> g18n.add_param("item_type", "messages")

// Translation templates
let translations = g18n.translations()
  |> g18n.add_translation("user.welcome", "Welcome {name}!")
  |> g18n.add_translation("user.messages", "You have {count} new {item_type}")
  |> g18n.add_translation("user.profile", "{firstName} {lastName} - {email}")

// Usage
g18n.translate_with_params(translator, "user.welcome", params)
// Result: "Welcome Alice!"
```

### Advanced Parameter Patterns

```gleam
// Conditional parameters (handled by application logic)
"status.online"   → "User {name} is online"
"status.offline"  → "User {name} was last seen {last_seen}"

// Nested object parameters (flattened in params)
let params = g18n.format_params()
  |> g18n.add_param("user_name", "user.name")
  |> g18n.add_param("user_email", "user.email")
  |> g18n.add_param("user_role", "user.role")

"user.info" → "{user_name} ({user_email}) - {user_role}"
```

---

## Pluralization Syntax

### Plural Form Suffixes

g18n uses **CLDR plural rule suffixes** for different grammatical forms:

```gleam
// Standard CLDR plural forms
".zero"    // Exactly 0 items
".one"     // Exactly 1 item  
".two"     // Exactly 2 items
".few"     // Small quantities (language-specific)
".many"    // Large quantities (language-specific)
".other"   // Default/fallback form
```

### Language-Specific Pluralization

#### English (Simple: One/Other)

```json
{
  "item.one": "1 item",
  "item.other": "{count} items"
}
```

#### Portuguese (Zero/One/Other)

```json
{
  "item.zero": "nenhum item",
  "item.one": "1 item", 
  "item.other": "{count} itens"
}
```

#### French (One for 0,1 / Other for 2+)

```json
{
  "item.one": "{count} élément",     // Used for 0 and 1
  "item.other": "{count} éléments"   // Used for 2+
}
```

#### Arabic (Complex: 6 Forms)

```json
{
  "item.zero": "لا توجد عناصر",      // 0 items
  "item.one": "عنصر واحد",          // 1 item
  "item.two": "عنصران",             // 2 items  
  "item.few": "{count} عناصر",      // 3-10 items
  "item.many": "{count} عنصر",      // 11-99 items
  "item.other": "{count} عنصر"      // 100+ items
}
```

#### Russian (Complex: One/Few/Many)

```json
{
  "item.one": "{count} предмет",     // 1, 21, 31, 41... (ends in 1, not 11)
  "item.few": "{count} предмета",    // 2-4, 22-24, 32-34... (ends in 2-4, not 12-14)
  "item.many": "{count} предметов"   // 0, 5-20, 25-30, 35-40... (everything else)
}
```

#### Chinese/Japanese/Korean (No Pluralization)

```json
{
  "item.other": "{count}个项目"      // Same form for all counts
}
```

### Plural Usage Patterns

```gleam
// Cardinal numbers (regular counting)
g18n.translate_plural(translator, "item", 0)   // Uses .zero (if available) or .other
g18n.translate_plural(translator, "item", 1)   // Uses .one
g18n.translate_plural(translator, "item", 5)   // Uses .other

// Ordinal numbers (rankings/positions)
g18n.translate_ordinal(translator, "position", 1)   // "1st place"
g18n.translate_ordinal(translator, "position", 2)   // "2nd place"  
g18n.translate_ordinal(translator, "position", 3)   // "3rd place"
g18n.translate_ordinal(translator, "position", 4)   // "4th place"

// Range numbers (selections)
g18n.translate_range(translator, "selection", 1, 1)    // "1 item selected"
g18n.translate_range(translator, "selection", 3, 7)    // "3-7 items selected"
```

---

## Context-Sensitive Translations

### Context Syntax

Context uses the **@ symbol** to disambiguate words with multiple meanings:

```gleam
// Basic context syntax
"word"           // Default/no context
"word@context"   // Specific context

// Real-world examples
"bank"               // Generic term
"bank@financial"     // Financial institution
"bank@river"         // Riverbank  
"bank@turn"          // To lean/tilt

"may"                // Auxiliary verb
"may@month"          // Month name
"may@permission"     // Permission context
```

### Context Usage Patterns

```gleam
// Adding context translations
let translations = g18n.translations()
  |> g18n.add_translation("close", "close")                    // Default
  |> g18n.add_translation("close@door", "Close the {item}")    // Door context
  |> g18n.add_translation("close@application", "Close {app}")  // App context
  |> g18n.add_translation("close@window", "Close window")      // UI context

// Using context in code
g18n.translate_with_context(translator, "close", g18n.NoContext)        // "close"
g18n.translate_with_context(translator, "close", g18n.Context("door"))  // "Close the door"
g18n.translate_with_context(translator, "close", g18n.Context("app"))   // "Close MyApp"
```

### Context with Parameters

```gleam
// Context + parameters combined
let translations = g18n.translations()
  |> g18n.add_translation("open@file", "Open {filename}")
  |> g18n.add_translation("open@door", "Open the {location} door")
  |> g18n.add_translation("open@store", "Store opens at {time}")

let params = g18n.format_params()
  |> g18n.add_param("filename", "document.pdf")

g18n.translate_with_context_and_params(
  translator, 
  "open", 
  g18n.Context("file"), 
  params
) // "Open document.pdf"
```

### Context Best Practices

```gleam
// ✅ Good context naming
"run@exercise"          // Physical activity
"run@computer"          // Execute program  
"run@election"          // Campaign for office
"run@business"          // Operate a business

// ✅ Descriptive contexts
"address@home"          // Home address
"address@email"         // Email address
"address@speech"        // Formal speech
"address@problem"       // Deal with an issue

// ❌ Poor context naming
"run@1", "run@2"        // Non-descriptive numbers
"address@a", "address@b" // Unclear abbreviations
```

---

## JSON Format Syntax

### Flat JSON Format (g18n Optimized)

```json
{
  "ui.button.save": "Save",
  "ui.button.cancel": "Cancel", 
  "ui.dialog.confirm": "Are you sure?",
  "user.profile.name": "Full Name",
  "user.profile.email": "Email Address",
  "errors.validation.required": "This field is required",
  "errors.network.timeout": "Connection timed out"
}
```

### Nested JSON Format (Industry Standard)

```json
{
  "ui": {
    "button": {
      "save": "Save",
      "cancel": "Cancel"
    },
    "dialog": {
      "confirm": "Are you sure?"
    }
  },
  "user": {
    "profile": {
      "name": "Full Name",
      "email": "Email Address"
    }
  },
  "errors": {
    "validation": {
      "required": "This field is required"
    },
    "network": {
      "timeout": "Connection timed out"
    }
  }
}
```

### Pluralization in JSON

#### Flat Format

```json
{
  "item.zero": "no items",
  "item.one": "1 item",
  "item.other": "{count} items",
  "message.one": "1 message",
  "message.other": "{count} messages"
}
```

#### Nested Format

```json
{
  "item": {
    "zero": "no items",
    "one": "1 item", 
    "other": "{count} items"
  },
  "message": {
    "one": "1 message",
    "other": "{count} messages"
  }
}
```

### Context in JSON

#### Flat Format

```json
{
  "bank": "bank",
  "bank@financial": "financial institution",
  "bank@river": "riverbank",
  "may": "may",
  "may@month": "May",
  "may@permission": "allowed to"
}
```

#### Nested Format (Future Enhancement)

```json
{
  "bank": {
    "_default": "bank",
    "financial": "financial institution", 
    "river": "riverbank"
  },
  "may": {
    "_default": "may",
    "month": "May",
    "permission": "allowed to"
  }
}
```

---

## Date & Time Format Syntax

### Date Format Types

```gleam
// Built-in format types
g18n.Short     // 01/15/24
g18n.Medium    // Jan 15, 2024  
g18n.Long      // January 15, 2024
g18n.Full      // Monday, January 15, 2024 GMT

// Custom format patterns
g18n.Custom("YYYY-MM-DD")        // 2024-01-15
g18n.Custom("DD/MM/YYYY")        // 15/01/2024  
g18n.Custom("MMM DD, YYYY")      // Jan 15, 2024
g18n.Custom("EEEE, MMMM DD")     // Monday, January 15
```

### Custom Date Pattern Syntax

```gleam
// Date pattern symbols
"YYYY"    // 4-digit year (2024)
"YY"      // 2-digit year (24)
"MMMM"    // Full month name (January)
"MMM"     // Short month name (Jan)  
"MM"      // 2-digit month (01)
"DD"      // 2-digit day (15)
"EEEE"    // Full day name (Monday)
"EEE"     // Short day name (Mon)

// Example custom patterns
g18n.Custom("YYYY年MM月DD日")     // Chinese: 2024年01月15日
g18n.Custom("DD.MM.YYYY")         // German: 15.01.2024
g18n.Custom("DD de MMMM de YYYY") // Spanish: 15 de enero de 2024
g18n.Custom("MMMM DD일, YYYY년")   // Korean: 1월 15일, 2024년
```

### Time Format Patterns

```gleam
// Time format types
g18n.Short     // 2:30 PM (en) / 14:30 (pt)
g18n.Medium    // 2:30:45 PM
g18n.Long      // 2:30:45 PM GMT  
g18n.Full      // 2:30:45 PM Greenwich Mean Time

// Custom time patterns  
g18n.Custom("HH:mm")       // 24-hour: 14:30
g18n.Custom("hh:mm a")     // 12-hour: 02:30 PM
g18n.Custom("HH:mm:ss")    // With seconds: 14:30:45
```

### Relative Time Syntax

```gleam
// Relative time units
g18n.Minutes(30)    // 30 minutes
g18n.Hours(2)       // 2 hours
g18n.Days(3)        // 3 days
g18n.Weeks(1)       // 1 week
g18n.Months(6)      // 6 months  
g18n.Years(2)       // 2 years

// Direction
g18n.Past    // "ago" / "hace" / "前"
g18n.Future  // "from now" / "en" / "后"

// Examples
g18n.format_relative_time(en_translator, g18n.Hours(2), g18n.Past)
// "2 hours ago"

g18n.format_relative_time(es_translator, g18n.Days(3), g18n.Future)  
// "en 3 días"

g18n.format_relative_time(zh_translator, g18n.Minutes(30), g18n.Past)
// "30分钟前"
```

---

## Number Format Syntax

### Number Format Types

```gleam
// Basic number formatting
g18n.Decimal(precision)           // Decimal numbers
g18n.Currency(code, precision)    // Currency formatting
g18n.Percentage(precision)        // Percentage formatting  
g18n.Scientific(precision)        // Scientific notation
g18n.Compact                      // Compact notation (1.5K, 2.3M)

// Examples
g18n.format_number(translator, 1234.56, g18n.Decimal(2))
// English: "1,234.56"
// Portuguese: "1.234,56"

g18n.format_number(translator, 29.99, g18n.Currency("USD", 2))
// English: "$29.99" 
// Portuguese: "US$ 29,99"

g18n.format_number(translator, 0.75, g18n.Percentage(1))
// English: "75.0%"
// French: "75,0 %"

g18n.format_number(translator, 1500000.0, g18n.Compact)
// "1.5M" / "1,5M"
```

### Currency Code Syntax

```gleam
// ISO 4217 currency codes
"USD"    // US Dollar
"EUR"    // Euro
"GBP"    // British Pound
"JPY"    // Japanese Yen
"BRL"    // Brazilian Real
"CNY"    // Chinese Yuan
"INR"    // Indian Rupee
"AED"    // UAE Dirham

// Usage
g18n.Currency("EUR", 2)    // €29.99
g18n.Currency("JPY", 0)    // ¥2999 (no decimals)
g18n.Currency("BTC", 8)    // ₿0.00123456
```

---

## Locale Code Syntax

### Standard Locale Formats

```gleam
// Language only (ISO 639-1)
"en"    // English
"es"    // Spanish  
"pt"    // Portuguese
"fr"    // French
"de"    // German
"it"    // Italian
"ru"    // Russian
"ar"    // Arabic
"zh"    // Chinese
"ja"    // Japanese
"ko"    // Korean
"hi"    // Hindi

// Language + Region (ISO 639-1 + ISO 3166-1)
"en-US"    // English (United States)
"en-GB"    // English (United Kingdom)  
"es-ES"    // Spanish (Spain)
"es-MX"    // Spanish (Mexico)
"pt-BR"    // Portuguese (Brazil)
"pt-PT"    // Portuguese (Portugal)
"fr-FR"    // French (France)
"fr-CA"    // French (Canada)
"de-DE"    // German (Germany)
"de-AT"    // German (Austria)
"ar-SA"    // Arabic (Saudi Arabia)
"ar-EG"    // Arabic (Egypt)
"zh-CN"    // Chinese (China)
"zh-TW"    // Chinese (Taiwan)
```

### Locale Validation Rules

```gleam
// ✅ Valid locale codes
"en"          // Language code: 2 letters
"en-US"       // Language + region: 2 letters + dash + 2 letters
"pt-BR"       // Case insensitive (normalized to lowercase language, uppercase region)

// ❌ Invalid locale codes
"eng"         // Language too long
"en-USA"      // Region too long
"en_US"       // Wrong separator (should be dash, not underscore)
"EN-us"       // Mixed case (will be normalized)
""            // Empty string
"invalid"     // Not a standard format
```

### RTL/LTR Language Detection

```gleam
// RTL languages (Right-to-Left)
"ar"    // Arabic        → RTL
"he"    // Hebrew        → RTL  
"fa"    // Persian       → RTL
"ur"    // Urdu          → RTL
"ps"    // Pashto        → RTL
"yi"    // Yiddish       → RTL

// LTR languages (Left-to-Right) - Default
"en"    // English       → LTR
"es"    // Spanish       → LTR
"zh"    // Chinese       → LTR
"ja"    // Japanese      → LTR
// All others         → LTR

// Usage
g18n.get_text_direction(locale)  // Returns LTR or RTL
g18n.is_rtl(locale)              // Returns True/False
g18n.get_css_direction(locale)   // Returns "ltr"/"rtl"
```

---

## CLI Usage Syntax

### Command Structure

```bash
# Basic command syntax
gleam run [command] [arguments]

# Available commands
gleam run generate        # Generate from flat JSON files
gleam run generate_nested # Generate from nested JSON files (industry standard)
gleam run help           # Show help information
gleam run                # Default: shows help
```

### File Organization

```
project_root/
├── src/
│   └── my_project/
│       └── translations/          # Translation files directory
│           ├── en.json            # English translations (flat or nested)
│           ├── es.json            # Spanish translations (flat or nested)
│           ├── pt.json            # Portuguese translations (flat or nested)
│           ├── fr.json            # French translations (flat or nested)
│           └── translations.json  # Fallback single file
├── gleam.toml
└── README.md
```

### CLI Command Examples

#### Flat JSON Workflow
```bash
# Create flat JSON files
echo '{"ui.button.save": "Save", "user.name": "Name"}' > src/my_project/translations/en.json
echo '{"ui.button.save": "Guardar", "user.name": "Nombre"}' > src/my_project/translations/es.json

# Generate Gleam module
gleam run generate

# Output: src/my_project/translations.gleam with flat-to-trie conversion
```

#### Nested JSON Workflow  
```bash
# Create nested JSON files (react-i18next/Vue i18n format)
echo '{"ui":{"button":{"save":"Save"}},"user":{"name":"Name"}}' > src/my_project/translations/en.json
echo '{"ui":{"button":{"save":"Guardar"}},"user":{"name":"Nombre"}}' > src/my_project/translations/es.json

# Generate Gleam module from nested format
gleam run generate_nested

# Output: src/my_project/translations.gleam with nested-to-flat-to-trie conversion
```

### Generated Module Structure

```gleam
// Generated in src/my_project/translations.gleam

// Per-locale functions
pub fn en_translations() -> g18n.Translations { ... }
pub fn en_locale() -> Result(g18n.Locale, g18n.LocaleError) { ... }
pub fn en_translator() -> Result(g18n.Translator, g18n.LocaleError) { ... }

pub fn es_translations() -> g18n.Translations { ... }
pub fn es_locale() -> Result(g18n.Locale, g18n.LocaleError) { ... }
pub fn es_translator() -> Result(g18n.Translator, g18n.LocaleError) { ... }

// Utility functions
pub fn available_locales() -> List(String) { ... }
pub fn get_translator(locale_code: String) -> Result(g18n.Translator, g18n.LocaleError) { ... }
```

---

## Advanced Patterns

### Namespace Organization

```gleam
// Feature-based organization
"auth.login.email"           // Authentication → Login → Email field
"auth.login.password"        // Authentication → Login → Password field
"auth.signup.terms"          // Authentication → Signup → Terms  
"auth.forgot.instructions"   // Authentication → Forgot → Instructions

"dashboard.stats.users"      // Dashboard → Statistics → Users
"dashboard.stats.revenue"    // Dashboard → Statistics → Revenue
"dashboard.actions.export"   // Dashboard → Actions → Export

"settings.profile.name"      // Settings → Profile → Name
"settings.privacy.public"    // Settings → Privacy → Public option
"settings.notifications.email" // Settings → Notifications → Email
```

### Complex Message Patterns

```gleam
// Conditional messages based on count
"notification.messages.zero"  → "No new messages"
"notification.messages.one"   → "1 new message"  
"notification.messages.other" → "{count} new messages"

// Status-dependent messages
"user.status.online"    → "{name} is online"
"user.status.away"      → "{name} is away"  
"user.status.offline"   → "{name} was last seen {time}"

// Error message patterns
"errors.validation.email.format"     → "Please enter a valid email"
"errors.validation.password.length"  → "Password must be at least {min} characters"
"errors.network.timeout"             → "Request timed out after {seconds} seconds"
"errors.auth.invalid_credentials"    → "Invalid username or password"
```

### Multi-Language Pattern Examples

#### English

```json
{
  "user.welcome": "Welcome back, {name}!",
  "item.one": "1 item in cart",
  "item.other": "{count} items in cart"
}
```

#### Spanish  

```json
{
  "user.welcome": "¡Bienvenido de nuevo, {name}!",
  "item.one": "1 artículo en el carrito",
  "item.other": "{count} artículos en el carrito"
}
```

#### Arabic

```json
{
  "user.welcome": "مرحبا بعودتك، {name}!",
  "item.zero": "لا توجد عناصر في العربة",
  "item.one": "عنصر واحد في العربة", 
  "item.two": "عنصران في العربة",
  "item.few": "{count} عناصر في العربة",
  "item.many": "{count} عنصرًا في العربة",
  "item.other": "{count} عنصر في العربة"
}
```

### Accept-Language Header Syntax

```gleam
// Standard HTTP Accept-Language format
"en-US,en;q=0.9,fr;q=0.8,es;q=0.7"

// Parsing with g18n
let preferred = g18n.parse_accept_language("en-US,en;q=0.9,fr;q=0.8")
// Returns: [Ok(en-US), Ok(en), Ok(fr)]

// Quality values (q-values) - higher = more preferred
"en-US"        // q=1.0 (default, highest priority)
"en;q=0.9"     // q=0.9 (high priority)
"fr;q=0.8"     // q=0.8 (medium priority)  
"es;q=0.7"     // q=0.7 (low priority)
```

---

## Validation Syntax

### Translation Validation

```gleam
// Validate translation completeness
let report = g18n.validate_translations(
  primary_translations,    // Complete translation set (usually English)
  target_translations,     // Translation set to validate
  "es"                     // Target language code
)

// Validate specific translation parameters
let errors = g18n.validate_translation_parameters(
  translations,           // Translation set
  "user.welcome",        // Key to validate
  ["name", "email"],     // Expected parameters
  "en"                   // Language code
)
```

### Validation Report Format

```text
Translation Validation Report for: es
=====================================

ERRORS:
- Missing translation: ui.button.delete
- Parameter mismatch in 'user.welcome': Expected [name], Found [nombre]

WARNINGS:  
- Unused translation: old.legacy.key

STATISTICS:
- Total primary keys: 25
- Translated keys: 23
- Missing keys: 2
- Coverage: 92.0%
```

---

## Error Patterns

### Common Translation Errors

```gleam
// Missing translation - falls back to key
g18n.translate(translator, "missing.key")
// Returns: "missing.key"

// Missing parameter - shows template
g18n.translate_with_params(translator, "user.welcome", empty_params)
// Template: "Welcome {name}!" → Returns: "Welcome {name}!"

// Invalid locale code
g18n.locale("invalid-code")
// Returns: Error(InvalidLanguage("Language code must be 2 characters"))

// Malformed JSON
g18n.translations_from_json("invalid json")
// Returns: Error("Failed to parse JSON: ...")
```

### Error Handling Best Practices

```gleam
// ✅ Graceful error handling
case g18n.locale(user_locale) {
  Ok(locale) -> create_translator(locale)
  Error(_) -> {
    // Fall back to default locale
    let assert Ok(default_locale) = g18n.locale("en")
    create_translator(default_locale)
  }
}

// ✅ Parameter validation
let required_params = ["name", "email", "count"]
let validation_errors = g18n.validate_translation_parameters(
  translations, 
  "user.info", 
  required_params, 
  "en"
)

case list.is_empty(validation_errors) {
  True -> proceed_with_translation()
  False -> log_validation_errors(validation_errors)
}
```

---

## Integration Patterns

### React-style Integration

```gleam
// Component-based translation keys
"components.header.title"
"components.sidebar.menu"  
"components.footer.copyright"
"pages.home.welcome"
"pages.about.description"
"hooks.useAuth.login_required"
```

### API Response Patterns

```gleam
// API error messages
"api.errors.unauthorized"        → "Access denied"
"api.errors.not_found"          → "Resource not found"
"api.errors.validation_failed"  → "Validation failed"
"api.success.created"           → "Successfully created"
"api.success.updated"           → "Successfully updated"
```

### Form Validation Patterns  

```gleam
// Form field patterns
"forms.user.name.label"         → "Full Name"
"forms.user.name.placeholder"   → "Enter your full name"
"forms.user.name.required"      → "Name is required"
"forms.user.name.invalid"       → "Please enter a valid name"

"forms.email.label"             → "Email Address"
"forms.email.placeholder"       → "you@example.com"
"forms.email.format_error"      → "Please enter a valid email address"
```

---

## Best Practices Summary

### ✅ Recommended Patterns

1. **Hierarchical Organization**: Use dot notation for logical grouping
2. **Descriptive Keys**: Make keys self-documenting
3. **Consistent Naming**: Follow naming conventions across the project
4. **Context Usage**: Use @context for word disambiguation
5. **Proper Pluralization**: Define all required plural forms for target languages
6. **Parameter Validation**: Validate parameters match templates
7. **Fallback Strategy**: Always provide fallback translations
8. **Namespace Queries**: Use namespaces for bulk operations

### ❌ Anti-Patterns to Avoid

1. **Deep Nesting**: Avoid more than 4 levels (`a.b.c.d.e`)
2. **Inconsistent Naming**: Don't mix camelCase and snake_case
3. **Hard-coded Text**: Don't embed translatable text in code
4. **Missing Plurals**: Don't forget plural forms for count-based messages
5. **Parameter Mismatches**: Ensure parameters match between languages
6. **Context Overuse**: Don't add context unless truly needed for disambiguation
7. **Locale Assumptions**: Don't assume locale features (RTL, plurals, etc.)

---

## Migration from Other Libraries

### From react-i18next

```javascript
// react-i18next nested format
{
  "auth": {
    "login": "Log in",
    "signup": "Sign up"
  }
}
```

```gleam
// g18n equivalent (both formats work)
// Option 1: Import nested directly
let assert Ok(translations) = g18n.translations_from_nested_json(nested_json)

// Option 2: Use flat format  
let translations = g18n.translations()
  |> g18n.add_translation("auth.login", "Log in")
  |> g18n.add_translation("auth.signup", "Sign up")
```

### From Vue i18n

```javascript
// Vue i18n format
{
  "message": {
    "hello": "Hello {name}"
  }
}
```

```gleam
// g18n equivalent
let translations = g18n.translations()
  |> g18n.add_translation("message.hello", "Hello {name}")

let params = g18n.format_params() |> g18n.add_param("name", "World")
g18n.translate_with_params(translator, "message.hello", params)
```

---

This syntax guide covers all the patterns and conventions used in g18n. For specific function documentation, refer to the inline /// comments in the source code or the generated documentation.

