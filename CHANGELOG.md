# Changelog

All notable changes to this project will be documented in this file.

## [3.0.0] - Unreleased

### Added
- **PO Plural Forms Support**: Complete support for PO plural forms (msgid_plural, msgstr[n])
  - Multi-form plural entries with proper index validation
  - Complex language support (Arabic 6-form, Russian 3-form, etc.)
  - Robust boundary detection for consecutive plural entries
  - Context + plural combination support

### Fixed
- **PO Parser Improvements**: Enhanced parsing reliability and error handling
  - Fixed multi-entry parsing boundary detection issues
  - Improved context + plural key generation (`notification.one@email` format)
  - Added msgstr[0] validation requirement for plural entries
  - Enhanced error detection for malformed PO syntax (msgid_plural without msgid)
  - Fixed string generation format issues in tests (literal `\n` vs actual newlines)

### Changed
- **CLI Migration**: Extracted CLI functionality to separate `g18n-dev` package
  - Core `g18n` library is now browser-compatible (removed Node.js dependencies)
  - CLI tools moved to `g18n-dev`: `generate`, `generate_nested`, `generate_po` commands
  - Development dependencies removed: `argv`, `shellout`, `simplifile`, `tom`, `filepath`
  - Breaking change: CLI functionality requires separate `g18n-dev` package installation

## [2.1.0]

### Added

- **PO File Support**: Complete gettext PO/POT file format support
  - `translations_from_po()` - Import PO file content into g18n translations
  - `translations_to_po()` - Export g18n translations to PO format
  - `generate_po` CLI command - Generate Gleam modules from PO files
  - Full PO format features: contexts (msgctxt), multiline strings, escape sequences
  - Comprehensive comment support: translator notes, source references, flags
  - Performance optimized for 1000+ translation entries
  - Seamless integration with existing g18n workflow and features

## [2.0.1] - 2025-09-08

### Fixed

- **BREAKING**: Fixed `translations_from_nested_json()` - Now properly handles deeply nested JSON structures
- **BREAKING**: Fixed ordinal suffix logic - `ordinal_suffix()` now includes position in output
- **BREAKING**: Fixed currency positioning for Spanish, French, and Italian locales (now displays "24€" instead of "€24")
- Fixed number precision formatting - 0 precision now shows "24" instead of "24.0", 2 precision shows "24.00" instead of "24.0"
- Fixed currency spacing - Spanish uses no space ("24€"), while French/German/Italian use space ("24 €")
- Improved nested JSON conversion using `decode.recursive` for better performance

## [2.0.0] - 2025-09-07

### Changed

- **BREAKING**: Major refactor and code reorganization
- Moved locale functions to separate `g18n/locale` module
- Cleaned up internal module structure
- Removed unnecessary internal files and dependencies

### Fixed

- Various bug fixes and performance improvements

## [1.1.0] - 2025-09-06

### Added

- **RTL/LTR Text Direction Support**: Added `TextDirection` type, `get_text_direction()`, `is_rtl()`, `get_css_direction()`
- **Locale Negotiation System**: Added `negotiate_locale()`, `parse_accept_language()`, `get_locale_quality_score()`
- **Complete Pluralization Coverage**: Added plural rules for 12 languages (Spanish, French, German, Italian, Arabic, Chinese, Japanese, Korean, Hindi)
- **Context-Sensitive Translations**: Added `TranslationContext` type, `translate_with_context()`, `add_context_translation()`
- **Advanced Translation Features**: Number formatting, date/time formatting, validation tools
- **CLI Code Generation**: Command-line tool for generating Gleam modules from JSON translation files

### Changed

- Expanded pluralization from 3/12 to 12/12 supported languages
- Enhanced locale support with comprehensive CLDR-based plural rules

## [1.0.0] - 2025-09-06

### Added

- Initial release of g18n internationalization library
- Core translation functionality with key-value lookups
- Parameter substitution in translation templates
- Basic pluralization support for English, Polish, and Russian
- Trie-based translation storage for efficient lookups
- JSON import/export functionality
- Locale creation and management
- Basic date/time formatting
- Comprehensive test suite and documentation
