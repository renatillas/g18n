# g18n Translation Syntax Guide

<!--toc:start-->
- [g18n Translation Syntax Guide](#g18n-translation-syntax-guide)
  - [Translation Keys](#translation-keys)
    - [Hierarchical Structure](#hierarchical-structure)
    - [Key Naming Rules](#key-naming-rules)
  - [Parameter Syntax](#parameter-syntax)
    - [Basic Parameters](#basic-parameters)
    - [Parameter Naming](#parameter-naming)
  - [Pluralization Syntax](#pluralization-syntax)
    - [Key Suffixes](#key-suffixes)
    - [Language Examples](#language-examples)
  - [Context Syntax](#context-syntax)
    - [Context Disambiguation](#context-disambiguation)
    - [Context with Parameters](#context-with-parameters)
  - [JSON Structure](#json-structure)
    - [Flat Format (Recommended)](#flat-format-recommended)
    - [Nested Format (React/Vue Style)](#nested-format-reactvue-style)
  - [Common Patterns](#common-patterns)
    - [Form Fields](#form-fields)
    - [Status Messages](#status-messages)
    - [Actions & Buttons](#actions-buttons)
    - [Error Messages](#error-messages)
    - [Navigation & UI](#navigation-ui)
  - [Best Practices](#best-practices)
    - [✅ Do](#do)
    - [❌ Don't](#don-t)
  - [Key Organization Examples](#key-organization-examples)
<!--toc:end-->

Quick reference for writing translations with the g18n library.

## Translation Keys

### Hierarchical Structure

Use dot notation to organize translations:

```
ui.button.save
ui.button.cancel
ui.dialog.confirm
user.profile.name
user.profile.email
errors.validation.required
errors.network.timeout
auth.login.title
auth.signup.terms
```

### Key Naming Rules

- Use lowercase letters and dots only
- Maximum 4 levels deep: `section.subsection.component.element`
- Be descriptive and consistent
- Group related translations together

```
✅ Good
"user.settings.privacy.visibility"
"cart.item.quantity.label"
"error.form.email.invalid"

❌ Avoid  
"usrSttngsPrivVis"           // Abbreviated
"user_settings_privacy"      // Underscores
"user.settings.privacy.visibility.option.public"  // Too deep
```

## Parameter Syntax

### Basic Parameters

Use curly braces `{name}` for dynamic values:

```
"Welcome {name}!"
"You have {count} messages"
"Hello {firstName} {lastName}"
"Order total: {amount} {currency}"
```

### Parameter Naming

- Use descriptive names: `{user_name}` not `{x}`
- Be consistent: snake_case or camelCase
- Match parameter names across all languages

```json
{
  "en": "Welcome back, {user_name}!",
  "es": "¡Bienvenido de vuelta, {user_name}!",
  "pt": "Bem-vindo de volta, {user_name}!"
}
```

## Pluralization Syntax

### Key Suffixes

Add plural form suffixes to base keys:

```
item.zero     // 0 items
item.one      // 1 item  
item.two      // 2 items (Arabic, Slavic languages)
item.few      // 3-10 items (Arabic, Slavic languages)
item.many     // 11+ items (Arabic, Slavic languages)
item.other    // Default/fallback form
```

### Language Examples

**English (Simple)**

```json
{
  "message.one": "1 message",
  "message.other": "{count} messages"
}
```

**Portuguese (With Zero)**

```json
{
  "item.zero": "nenhum item",
  "item.one": "1 item",
  "item.other": "{count} itens"
}
```

**Russian (Complex)**

```json
{
  "file.one": "{count} файл",     // 1, 21, 31, 41...
  "file.few": "{count} файла",    // 2-4, 22-24, 32-34...
  "file.many": "{count} файлов"   // 0, 5-20, 25-30...
}
```

**Arabic (Full CLDR)**

```json
{
  "book.zero": "لا توجد كتب",      // 0
  "book.one": "كتاب واحد",         // 1
  "book.two": "كتابان",           // 2
  "book.few": "{count} كتب",      // 3-10
  "book.many": "{count} كتاباً",   // 11-99
  "book.other": "{count} كتاب"    // 100+
}
```

## Context Syntax

### Context Disambiguation

Use `@context` to distinguish meanings:

```json
{
  "bank": "bank",
  "bank@financial": "financial institution",
  "bank@river": "riverbank",
  
  "close": "close",
  "close@door": "close the door", 
  "close@application": "quit application",
  
  "may": "may",
  "may@month": "May",
  "may@permission": "allowed to"
}
```

### Context with Parameters

```json
{
  "open@file": "Open {filename}",
  "open@door": "Open the {location} door",
  "open@store": "Store opens at {time}"
}
```

## JSON Structure

### Flat Format (Recommended)

```json
{
  "ui.button.save": "Save",
  "ui.button.cancel": "Cancel",
  "ui.dialog.confirm": "Are you sure?",
  "user.name": "Full Name",
  "user.email": "Email Address",
  "item.one": "1 item",
  "item.other": "{count} items",
  "bank@financial": "Bank",
  "bank@river": "Riverbank"
}
```

### Nested Format (React/Vue Style)

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
    "name": "Full Name",
    "email": "Email Address"
  },
  "item": {
    "one": "1 item",
    "other": "{count} items"
  }
}
```

## Common Patterns

### Form Fields

**Flat Format:**
```json
{
  "form.name.label": "Full Name",
  "form.name.placeholder": "Enter your name",
  "form.name.required": "Name is required",
  "form.name.invalid": "Please enter a valid name",
  
  "form.email.label": "Email",
  "form.email.placeholder": "you@example.com",
  "form.email.format": "Please enter a valid email"
}
```

**Nested Format:**
```json
{
  "form": {
    "name": {
      "label": "Full Name",
      "placeholder": "Enter your name",
      "required": "Name is required",
      "invalid": "Please enter a valid name"
    },
    "email": {
      "label": "Email",
      "placeholder": "you@example.com",
      "format": "Please enter a valid email"
    }
  }
}
```

### Status Messages

**Flat Format:**
```json
{
  "status.loading": "Loading...",
  "status.success": "Success!",
  "status.error": "An error occurred",
  "status.empty": "No items found",
  
  "user.online": "{name} is online",
  "user.away": "{name} is away",
  "user.offline": "{name} was last seen {time}"
}
```

**Nested Format:**
```json
{
  "status": {
    "loading": "Loading...",
    "success": "Success!",
    "error": "An error occurred",
    "empty": "No items found"
  },
  "user": {
    "online": "{name} is online",
    "away": "{name} is away",
    "offline": "{name} was last seen {time}"
  }
}
```

### Actions & Buttons

**Flat Format:**
```json
{
  "action.save": "Save",
  "action.cancel": "Cancel", 
  "action.delete": "Delete",
  "action.confirm": "Confirm",
  "action.edit": "Edit",
  "action.create": "Create",
  
  "button.save.saving": "Saving...",
  "button.delete.confirm": "Are you sure you want to delete {item}?"
}
```

**Nested Format:**
```json
{
  "action": {
    "save": "Save",
    "cancel": "Cancel",
    "delete": "Delete",
    "confirm": "Confirm",
    "edit": "Edit",
    "create": "Create"
  },
  "button": {
    "save": {
      "saving": "Saving..."
    },
    "delete": {
      "confirm": "Are you sure you want to delete {item}?"
    }
  }
}
```

### Error Messages

**Flat Format:**
```json
{
  "error.network": "Network error",
  "error.timeout": "Request timed out",
  "error.unauthorized": "Access denied",
  "error.notfound": "Not found",
  
  "error.validation.required": "This field is required",
  "error.validation.email": "Please enter a valid email",
  "error.validation.min": "Must be at least {min} characters",
  "error.validation.max": "Cannot exceed {max} characters"
}
```

**Nested Format:**
```json
{
  "error": {
    "network": "Network error",
    "timeout": "Request timed out",
    "unauthorized": "Access denied",
    "notfound": "Not found",
    "validation": {
      "required": "This field is required",
      "email": "Please enter a valid email",
      "min": "Must be at least {min} characters",
      "max": "Cannot exceed {max} characters"
    }
  }
}
```

### Navigation & UI

**Flat Format:**
```json
{
  "nav.home": "Home",
  "nav.about": "About", 
  "nav.contact": "Contact",
  "nav.profile": "Profile",
  
  "header.title": "My Application",
  "footer.copyright": "© {year} Company Name",
  
  "pagination.prev": "Previous",
  "pagination.next": "Next",
  "pagination.page": "Page {current} of {total}"
}
```

**Nested Format:**
```json
{
  "nav": {
    "home": "Home",
    "about": "About",
    "contact": "Contact",
    "profile": "Profile"
  },
  "header": {
    "title": "My Application"
  },
  "footer": {
    "copyright": "© {year} Company Name"
  },
  "pagination": {
    "prev": "Previous",
    "next": "Next",
    "page": "Page {current} of {total}"
  }
}
```

## Best Practices

### ✅ Do

- Use descriptive, hierarchical keys
- Keep parameter names consistent across languages  
- Provide all required plural forms for each language
- Use context only when truly needed for disambiguation
- Group related translations logically
- Test with long translations to check UI layout

### ❌ Don't

- Hardcode translatable text in your code
- Use abbreviations or cryptic key names
- Mix different naming conventions
- Assume all languages work like English
- Forget to handle plural forms
- Create overly deep key hierarchies (max 4 levels)

## Key Organization Examples

**Flat Format:**
```json
{
  // Authentication flow
  "auth.login.title": "Sign In",
  "auth.login.email": "Email", 
  "auth.login.password": "Password",
  "auth.login.submit": "Sign In",
  "auth.login.forgot": "Forgot password?",
  
  "auth.signup.title": "Create Account",
  "auth.signup.name": "Full Name",
  "auth.signup.email": "Email Address",
  "auth.signup.password": "Choose Password",
  "auth.signup.confirm": "Confirm Password",
  "auth.signup.terms": "I agree to the terms",
  
  // Dashboard sections
  "dashboard.header.title": "Dashboard",
  "dashboard.stats.users": "Total Users",
  "dashboard.stats.revenue": "Revenue",
  "dashboard.actions.export": "Export Data",
  
  // Settings categories  
  "settings.profile.title": "Profile Settings",
  "settings.profile.name": "Display Name",
  "settings.profile.avatar": "Profile Picture",
  
  "settings.privacy.title": "Privacy Settings", 
  "settings.privacy.public": "Public Profile",
  "settings.privacy.search": "Searchable"
}
```

**Nested Format:**
```json
{
  "auth": {
    "login": {
      "title": "Sign In",
      "email": "Email",
      "password": "Password",
      "submit": "Sign In",
      "forgot": "Forgot password?"
    },
    "signup": {
      "title": "Create Account",
      "name": "Full Name",
      "email": "Email Address",
      "password": "Choose Password",
      "confirm": "Confirm Password",
      "terms": "I agree to the terms"
    }
  },
  "dashboard": {
    "header": {
      "title": "Dashboard"
    },
    "stats": {
      "users": "Total Users",
      "revenue": "Revenue"
    },
    "actions": {
      "export": "Export Data"
    }
  },
  "settings": {
    "profile": {
      "title": "Profile Settings",
      "name": "Display Name",
      "avatar": "Profile Picture"
    },
    "privacy": {
      "title": "Privacy Settings",
      "public": "Public Profile",
      "search": "Searchable"
    }
  }
}
```

