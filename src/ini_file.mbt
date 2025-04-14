///|
priv enum Section {
  Global
  NamedSection(String)
} derive(Eq, Hash, Show)

///|
priv type Key String derive(Eq, Hash, Show)

///|
priv type Value String derive(Eq, Hash, Show)

///|
struct IniFile {
  sections : @hashmap.T[Section, @hashmap.T[Key, Value]]
  // default not case sensitive
  is_case_sensitive : Bool
}

///|
pub fn IniFile::new(is_case_sensitive~ : Bool = false) -> IniFile {
  IniFile::{ sections: @hashmap.new(), is_case_sensitive }
}

///|
fn IniFile::new_with_sections(
  sections : @hashmap.T[Section, @hashmap.T[Key, Value]],
  is_case_sensitive~ : Bool = false
) -> IniFile {
  IniFile::{ sections, is_case_sensitive }
}

///|
fn IniFile::lower_if_needed(self : IniFile, s : String) -> String {
  if self.is_case_sensitive {
    s
  } else {
    s.to_lower()
  }
}

///| get is a alias for get_string
pub fn IniFile::get(
  self : IniFile,
  section~ : String = "",
  key : String
) -> String? {
  self.get_string(section~, key)
}

///|
pub fn IniFile::get_string(
  self : IniFile,
  section~ : String = "",
  key : String
) -> String? {
  let section_map = self.get_section(
    match section {
      "" => Section::Global
      _ => Section::NamedSection(self.lower_if_needed(section))
    },
    create_if_not_exists=false,
  )
  guard not(section_map.is_empty()) else { None }
  let section_map = section_map.unwrap()
  let value = section_map.get(self.lower_if_needed(key))
  guard not(value.is_empty()) else { None }
  let value = value.unwrap()
  let Value(v) = value
  Some(v)
}

///|
pub fn IniFile::get_bool(
  self : IniFile,
  section~ : String = "",
  key : String
) -> Bool? {
  let value = self.get_string(section~, key)
  guard not(value.is_empty()) else { None }
  let value = value.unwrap()
  match value.to_lower() {
    "true" | "yes" | "on" => Some(true)
    "false" | "no" | "off" => Some(false)
    _ => Some(false)
  }
}

// TODO: Add support for other types like Int, Float, etc.

///|
fn IniFile::get_section(
  self : IniFile,
  section : Section,
  create_if_not_exists~ : Bool = false
) -> @hashmap.T[Key, Value]? {
  let section_map = self.sections.get(section)
  match section_map {
    None =>
      if create_if_not_exists {
        let new_section = @hashmap.new()
        self.sections.set(section, new_section)
        Some(new_section)
      } else {
        None
      }
    Some(_) => section_map
  }
}

///|
fn IniFile::get_section_or_create(
  self : IniFile,
  section : Section
) -> @hashmap.T[Key, Value] {
  let section_map = self.get_section(section, create_if_not_exists=true)
  section_map.unwrap()
}

///|
pub fn IniFile::set(
  self : IniFile,
  section~ : String = "",
  key : String,
  value : String
) -> Unit {
  let section_map = self.get_section_or_create(
    match section {
      "" => Section::Global
      _ => Section::NamedSection(self.lower_if_needed(section))
    },
  )
  section_map.set(self.lower_if_needed(key), Value(value))
}

///|
test "INIFile::new/default_case_sensitivity" {
  let ini = IniFile::new()
  inspect!(ini.is_case_sensitive, content="false")
}

///|
test "INIFile::new/case_sensitive_true" {
  let ini = IniFile::new(is_case_sensitive=true)
  inspect!(ini.is_case_sensitive, content="true")
}

///|
test "INIFile::new/case_sensitive_false" {
  let ini = IniFile::new(is_case_sensitive=false)
  inspect!(ini.is_case_sensitive, content="false")
}

///|
test "INIFile::get/basic_functionality" {
  let ini = IniFile::new()
    ..set(section="section1", "key1", "value1")
    ..set("key2", "value2")
  inspect!(ini.get(section="section1", "key1"), content="Some(\"value1\")")
  inspect!(ini.get("key2"), content="Some(\"value2\")")
  inspect!(ini.get(section="nonexistent", "key1"), content="None")
  inspect!(ini.get("nonexistent"), content="None")
}

///|
test "INIFile::get/case_sensitivity" {
  let ini = IniFile::new(is_case_sensitive=true)..set(
    section="Section",
    "Key",
    "value",
  )
  inspect!(ini.get(section="Section", "Key"), content="Some(\"value\")")
  inspect!(ini.get(section="section", "Key"), content="None")
  inspect!(ini.get(section="Section", "key"), content="None")
}

///|
test "INIFile::get/empty_strings" {
  let ini = IniFile::new()
    ..set(section="", "key", "value")
    ..set(section="section", "", "value")
  inspect!(ini.get(section="", "key"), content="Some(\"value\")")
  inspect!(ini.get(section="section", ""), content="Some(\"value\")")
}

///|
test "INIFile::get_bool/true_values" {
  let ini = IniFile::new()
    ..set("key1", "true")
    ..set("key2", "yes")
    ..set("key3", "on")
    ..set(section="test", "key4", "TRUE")
    ..set(section="test", "key5", "Yes")
    ..set(section="test", "key6", "ON")
  inspect!(ini.get_bool("key1"), content="Some(true)")
  inspect!(ini.get_bool("key2"), content="Some(true)")
  inspect!(ini.get_bool("key3"), content="Some(true)")
  inspect!(ini.get_bool(section="test", "key4"), content="Some(true)")
  inspect!(ini.get_bool(section="test", "key5"), content="Some(true)")
  inspect!(ini.get_bool(section="test", "key6"), content="Some(true)")
}

///|
test "INIFile::get_bool/false_values" {
  let ini = IniFile::new()
    ..set("key1", "false")
    ..set("key2", "no")
    ..set("key3", "off")
    ..set("key4", "invalid")
  inspect!(ini.get_bool("key1"), content="Some(false)")
  inspect!(ini.get_bool("key2"), content="Some(false)")
  inspect!(ini.get_bool("key3"), content="Some(false)")
  inspect!(ini.get_bool("key4"), content="Some(false)")
}

///|
test "INIFile::get_bool/nonexistent_values" {
  let ini = IniFile::new()
  inspect!(ini.get_bool(section="nonexistent", "key"), content="None")
  inspect!(ini.get_bool("nonexistent"), content="None")
}

///|
test "INIFile::set/basic_functionality" {
  let ini = IniFile::new()..set("key", "value")
  inspect!(ini.get("key"), content="Some(\"value\")")
  ini.set(section="section", "key", "value")
  inspect!(ini.get(section="section", "key"), content="Some(\"value\")")
}

///|
test "INIFile::set/case_sensitivity" {
  let ini = IniFile::new(is_case_sensitive=true)
    ..set(section="Section", "Key", "value1")
    ..set(section="section", "key", "value2")
  inspect!(ini.get(section="Section", "Key"), content="Some(\"value1\")")
  inspect!(ini.get(section="section", "key"), content="Some(\"value2\")")
}

///|
test "INIFile::set/overwrite" {
  let ini = IniFile::new()..set("key", "value1")..set("key", "value2")
  inspect!(ini.get("key"), content="Some(\"value2\")")
  ini
  ..set(section="section", "key", "value1")
  .set(section="section", "key", "value2")
  inspect!(ini.get(section="section", "key"), content="Some(\"value2\")")
}
