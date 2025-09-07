import g18n
import g18n/locale

pub fn fr_translations() -> g18n.Translations {
  g18n.new_translations()
  |> g18n.add_translation("item.one", "1 élément")
  |> g18n.add_translation("item.other", "{count} éléments")
  |> g18n.add_translation("ui.button.cancel", "Annuler")
  |> g18n.add_translation("ui.button.save", "Sauvegarder")
  |> g18n.add_translation("user.welcome", "Bienvenue {name}!")
}

pub fn fr_locale() -> locale.Locale {
  let assert Ok(locale) = locale.new("fr")
  locale
}

pub fn fr_translator() -> g18n.Translator {
  g18n.new_translator(fr_locale(), fr_translations())
}

pub fn en_us_translations() -> g18n.Translations {
  g18n.new_translations()
  |> g18n.add_translation("goodbye", "Goodbye")
  |> g18n.add_translation("hello", "Hello")
  |> g18n.add_translation("item.one", "1 item")
  |> g18n.add_translation("item.other", "{count} items")
  |> g18n.add_translation("welcome", "Welcome {name}!")
}

pub fn en_us_locale() -> locale.Locale {
  let assert Ok(locale) = locale.new("en-us")
  locale
}

pub fn en_us_translator() -> g18n.Translator {
  g18n.new_translator(en_us_locale(), en_us_translations())
}

pub fn es_translations() -> g18n.Translations {
  g18n.new_translations()
  |> g18n.add_translation("goodbye", "Adiós")
  |> g18n.add_translation("hello", "Hola")
  |> g18n.add_translation("item.one", "1 artículo")
  |> g18n.add_translation("item.other", "{count} artículos")
  |> g18n.add_translation("welcome", "¡Bienvenido {name}!")
}

pub fn es_locale() -> locale.Locale {
  let assert Ok(locale) = locale.new("es")
  locale
}

pub fn es_translator() -> g18n.Translator {
  g18n.new_translator(es_locale(), es_translations())
}

pub fn available_locales() -> List(String) {
  ["fr", "en_us", "es"]
}
