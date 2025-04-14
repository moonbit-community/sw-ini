///|
pub type! IniParseError {
  UnexpectedEqualSign(line~ : Int, col~ : Int)
  EmptySection(line~ : Int, col~ : Int)
  UnclosedSection(line~ : Int, col~ : Int)
  ValueWithoutSection(line~ : Int, col~ : Int)
  QuoteMismatch(line~ : Int, col~ : Int)
  QuoteNotClosed(line~ : Int, col~ : Int)
}

///|
priv struct ParseContext {
  mut current_section : Section
  sections : @hashmap.T[Section, @hashmap.T[Key, Value]]
  mut line : Int
  mut col : Int
  mut key : String
  buffer : StringBuilder
}

///|
priv enum ReadingValueState {
  None
  SingleQuote
  DoubleQuote
} derive(Show)

///|
priv enum ParsePhase {
  Start
  ReadingSection
  ReadingKey
  ReadingValue(ReadingValueState)
  InComment
} derive(Show)

///|
struct IniParseState {
  ctx : ParseContext
  mut phase : ParsePhase
  is_case_sensitive : Bool
}

///|
fn IniParseState::lower_if_needed(self : IniParseState, s : String) -> String {
  if self.is_case_sensitive {
    s
  } else {
    s.to_lower()
  }
}

///|
pub fn IniParseState::new(is_case_sensitive~ : Bool = false) -> IniParseState {
  IniParseState::{
    ctx: ParseContext::{
      current_section: Section::Global,
      sections: @hashmap.from_array([(Section::Global, @hashmap.new())]),
      line: 1,
      col: 1,
      key: "",
      buffer: StringBuilder::new(),
    },
    phase: ParsePhase::Start,
    is_case_sensitive,
  }
}

///|
pub fn parse(
  str : String,
  is_case_sensitive~ : Bool = false
) -> IniFile!IniParseError {
  IniParseState::new(is_case_sensitive~).parse!(str).finish!()
}

///|
pub fn IniParseState::parse(
  self : IniParseState,
  chunk : String
) -> IniParseState!IniParseError {
  let mut self = self
  for c in chunk.iter() {
    self = self.process_char!(c)
  }
  self
}

///|
pub fn IniParseState::finish(self : IniParseState) -> IniFile!IniParseError {
  let self = self.process_char!('\n')
  IniFile::new_with_sections(
    self.ctx.sections,
    is_case_sensitive=self.is_case_sensitive,
  )
}

///|
fn IniParseState::process_char(
  self : IniParseState,
  c : Char
) -> IniParseState!IniParseError {
  self.update_position(c)
  match self.phase {
    ParsePhase::Start => self.handle_start!(c)
    ParsePhase::ReadingSection => self.handle_section_char!(c)
    ParsePhase::ReadingKey => self.handle_key_char!(c)
    ParsePhase::ReadingValue(_) => self.handle_value_char!(c)
    ParsePhase::InComment => self.handle_comment(c)
  }
}

///|
fn IniParseState::update_position(self : IniParseState, c : Char) -> Unit {
  if c == '\n' {
    self.ctx.line += 1
    self.ctx.col = 1
  } else {
    self.ctx.col += 1
  }
}

///|
fn IniParseState::handle_start(
  self : IniParseState,
  c : Char
) -> IniParseState!IniParseError {
  match c {
    '[' => {
      self.phase = ReadingSection
      self.ctx.buffer.reset()
      self
    }
    '#' | ';' => {
      self.phase = InComment
      self
    }
    '=' =>
      raise IniParseError::UnexpectedEqualSign(
        line=self.ctx.line,
        col=self.ctx.col,
      )
    '\n' => self.reset_line()
    _ if c.is_whitespace() => self
    _ => {
      self.phase = ReadingKey
      self.ctx.buffer.write_char(c)
      self
    }
  }
}

///|
fn IniParseState::handle_section_char(
  self : IniParseState,
  c : Char
) -> IniParseState!IniParseError {
  match c {
    '#' | ';' =>
      raise IniParseError::UnclosedSection(line=self.ctx.line, col=self.ctx.col)
    ']' => {
      if self.ctx.buffer.is_empty() {
        raise IniParseError::EmptySection(line=self.ctx.line, col=self.ctx.col)
      }
      let section_name = self.ctx.buffer.to_string().trim_space()
      let section_name = self.lower_if_needed(section_name)
      self.ctx.current_section = Section::NamedSection(section_name)
      self.ctx.sections.set(self.ctx.current_section, @hashmap.new())
      self.phase = Start
      self
    }
    '\n' =>
      raise IniParseError::UnclosedSection(line=self.ctx.line, col=self.ctx.col)
    _ => {
      self.ctx.buffer.write_char(c)
      self
    }
  }
}

///|
fn IniParseState::handle_key_char(
  self : IniParseState,
  c : Char
) -> IniParseState!IniParseError {
  match c {
    '=' => {
      if self.ctx.buffer.is_empty() {
        raise IniParseError::UnexpectedEqualSign(
          line=self.ctx.line,
          col=self.ctx.col,
        )
      }
      let key = self.ctx.buffer.to_string().trim_space()
      let key = self.lower_if_needed(key)
      self.ctx.buffer.reset()
      self.phase = ReadingValue(ReadingValueState::None)
      self.ctx.key = key
      self
    }
    '\n' | ';' | '#' => {
      let key = self.ctx.buffer.to_string().trim_space()
      if not(key.is_empty()) {
        let key = self.lower_if_needed(key)
        self.ctx.key = key
        self.ctx.buffer.reset()
        ignore(self.commit_value!())
      }
      self.reset_line()
    }
    _ if c.is_whitespace() =>
      match self.ctx.buffer.is_empty() {
        true => self
        false => {
          self.ctx.buffer.write_char(c)
          self
        }
      }
    _ => {
      self.ctx.buffer.write_char(c)
      self
    }
  }
}

///|
fn IniParseState::handle_value_char(
  self : IniParseState,
  c : Char
) -> IniParseState!IniParseError {
  match c {
    '\n' => {
      guard self.phase is ReadingValue(ReadingValueState::None) else {
        raise IniParseError::QuoteNotClosed(
          line=self.ctx.line,
          col=self.ctx.col,
        )
      }
      ignore(self.commit_value!())
      self.reset_line()
    }
    ';' | '#' => {
      guard self.phase is ReadingValue(ReadingValueState::None) else {
        raise IniParseError::QuoteNotClosed(
          line=self.ctx.line,
          col=self.ctx.col,
        )
      }
      ignore(self.commit_value!(drop_last_one_space=true))
      self.phase = InComment
      self
    }
    '\'' => {
      if self.phase is ReadingValue(ReadingValueState::DoubleQuote) {
        raise IniParseError::QuoteMismatch(line=self.ctx.line, col=self.ctx.col)
      }
      self.phase = match self.phase {
        ReadingValue(ReadingValueState::None) =>
          ReadingValue(ReadingValueState::SingleQuote)
        ReadingValue(ReadingValueState::SingleQuote) =>
          ReadingValue(ReadingValueState::None)
        _ => self.phase
      }
      self
    }
    '"' => {
      if self.phase is ReadingValue(ReadingValueState::SingleQuote) {
        raise IniParseError::QuoteMismatch(line=self.ctx.line, col=self.ctx.col)
      }
      self.phase = match self.phase {
        ReadingValue(ReadingValueState::None) =>
          ReadingValue(ReadingValueState::DoubleQuote)
        ReadingValue(ReadingValueState::DoubleQuote) =>
          ReadingValue(ReadingValueState::None)
        _ => self.phase
      }
      self
    }
    _ if c.is_whitespace() => {
      match self.phase {
        ReadingValue(ReadingValueState::None) =>
          if not(self.ctx.buffer.is_empty()) {
            self.ctx.buffer.write_char(c)
          }
        ReadingValue(ReadingValueState::SingleQuote) =>
          self.ctx.buffer.write_char(c)
        ReadingValue(ReadingValueState::DoubleQuote) =>
          self.ctx.buffer.write_char(c)
        _ => ()
      }
      self
    }
    _ => {
      self.ctx.buffer.write_char(c)
      self
    }
  }
}

///|
fn IniParseState::handle_comment(
  self : IniParseState,
  c : Char
) -> IniParseState {
  match c {
    '\n' => self.reset_line()
    _ => self
  }
}

///|
fn IniParseState::reset_line(self : IniParseState) -> IniParseState {
  self.phase = Start
  self.ctx.buffer.reset()
  self
}

///|
fn IniParseState::commit_value(
  self : IniParseState,
  // If true, drop the last space in the value
  // this is used to handle the case when a comment is at the end of the line
  drop_last_one_space~ : Bool = false
) -> IniParseState!IniParseError {
  let mut value = self.ctx.buffer.to_string()
  if drop_last_one_space && value.rev_iter().nth(0).unwrap().is_whitespace() {
    value = value.substring(end=value.length() - 1)
  }
  let section = self.ctx.sections.get(self.ctx.current_section)
  if section.is_empty() {
    raise IniParseError::ValueWithoutSection(
      line=self.ctx.line,
      col=self.ctx.col,
    )
  }
  let section = section.unwrap()
  let key = self.ctx.key
  guard not(key.is_blank()) else {
    raise IniParseError::ValueWithoutSection(
      line=self.ctx.line,
      col=self.ctx.col,
    )
  }
  section.set(key, value)
  self.ctx.buffer.reset()
  self
}

///|
test "IniParseState::new/default_settings" {
  let state = IniParseState::new()
  inspect!(state.is_case_sensitive, content="false")
  inspect!(state.ctx.line, content="1")
  inspect!(state.ctx.col, content="1")
  inspect!(state.ctx.key, content="")
  inspect!(state.phase, content="Start")
  inspect!(state.ctx.current_section, content="Global")
}

///|
test "IniParseState::new/case_sensitive" {
  let state = IniParseState::new(is_case_sensitive=true)
  inspect!(state.is_case_sensitive, content="true")
  inspect!(state.ctx.current_section, content="Global")
}

///|
test "IniParseState::new/buffer_empty" {
  let state = IniParseState::new()
  inspect!(state.ctx.buffer.is_empty(), content="true")
}

///|
test "IniParseState::process_char/start_phase" {
  let state = IniParseState::new()
  // Test transition from Start to ReadingSection
  let state = state.process_char!('[')
  inspect!(state.phase, content="ReadingSection")
  // Test transition from Start to InComment
  let state = IniParseState::new().process_char!(';')
  inspect!(state.phase, content="InComment")
  // Test transition from Start to ReadingKey
  let state = IniParseState::new().process_char!('a')
  inspect!(state.phase, content="ReadingKey")
}

///|
test "panic IniParseState::process_char/invalid_equal_sign" {
  let state = IniParseState::new()
  ignore(state.process_char!('='))
}

///|
test "panic IniParseState::process_char/unclosed_section" {
  let state = IniParseState::new()
  let state = state.process_char!('[')
  ignore(state.process_char!('\n'))
}

///|
test "panic IniParseState::process_char/unexpected_equal_sign" {
  let state = IniParseState::new()
  ignore(state.process_char!('='))
}

///|
test "IniParseState::process_char/global_section_edge_cases" {
  let state = IniParseState::new()
  inspect!(state.process_char!('[').phase, content="ReadingSection")
  inspect!(state.process_char!('G').phase, content="ReadingSection")
  let tmp = state.process_char!(']')
  inspect!(tmp.phase, content="Start")
  inspect!(tmp.ctx.current_section, content="NamedSection(\"g\")")
  inspect!(state.process_char!('[').phase, content="ReadingSection")
  assert_true!(tmp.process_char?('#') is Err(IniParseError::UnclosedSection(_)))
}

///|
test "panic IniParseState::process_char/unclosed_section" {
  let state = IniParseState::new()
  ignore(state.process_char!('['))
  ignore(state.process_char!('\n'))
}

///|
test "IniParseState::handle_start/reading_section" {
  let state = IniParseState::new()
  let updated_state = state.handle_start!('[')
  inspect!(updated_state.phase, content="ReadingSection")
  inspect!(updated_state.ctx.buffer.is_empty(), content="true")
}

///|
test "panic IniParseState::handle_start/unexpected_equal_sign" {
  let state = IniParseState::new()
  ignore(state.handle_start!('='))
}

///|
test "IniParseState::handle_start/in_comment" {
  let state = IniParseState::new()
  let updated_state = state.handle_start!('#')
  inspect!(updated_state.phase, content="InComment")
}

///|
test "IniParseState::handle_section_char/basic" {
  let state = IniParseState::new()
  // Test normal section name
  let state = state
    .handle_section_char!('t')
    .handle_section_char!('e')
    .handle_section_char!('s')
    .handle_section_char!('t')
    .handle_section_char!(']')
  inspect!(state.ctx.current_section, content="NamedSection(\"test\")")
  inspect!(state.phase, content="Start")
}

///|
test "panic IniParseState::handle_section_char/empty_section" {
  let state = IniParseState::new()
  ignore(state.handle_section_char!(']'))
}

///|
test "IniParseState::handle_section_char/unclosed_section" {
  fn new_state() -> IniParseState!IniParseError {
    IniParseState::new().handle_section_char!('t')
  }

  // Test both comment characters
  assert_true!(
    new_state!().handle_section_char?('#')
    is Err(IniParseError::UnclosedSection(_)),
  )
  assert_true!(
    new_state!().handle_section_char?(';')
    is Err(IniParseError::UnclosedSection(_)),
  )

  // Test newline
  assert_true!(
    new_state!().handle_section_char?('\n')
    is Err(IniParseError::UnclosedSection(_)),
  )
}

///|
test "IniParseState::handle_key_char/basic" {
  let state = IniParseState::new()
  let state = state.handle_key_char!('k')
  let state = state.handle_key_char!('e')
  let state = state.handle_key_char!('y')
  let state = state.handle_key_char!('=')
  inspect!(state.ctx.key, content="key")
  inspect!(state.phase, content="ReadingValue(None)")
  inspect!(state.ctx.buffer.is_empty(), content="true")
}

///|
test "panic IniParseState::handle_key_char/empty_buffer" {
  let state = IniParseState::new()
  ignore(state.handle_key_char!('='))
}

///|
test "IniParseState::handle_key_char/whitespace" {
  let state = IniParseState::new()
  // Leading whitespace should be ignored
  let state = state.handle_key_char!(' ')
  inspect!(state.ctx.buffer.is_empty(), content="true")

  // Key characters should be recorded
  let state = state.handle_key_char!('k')
  let state = state.handle_key_char!('e')
  let state = state.handle_key_char!('y')

  // Trailing whitespace should be recorded after first non-whitespace
  let state = state.handle_key_char!(' ')
  inspect!(state.ctx.buffer.to_string(), content="key ")
}

///|
test "IniParseState::handle_key_char/valueless_key" {
  let state = IniParseState::new()
  let state = state.handle_key_char!('k')
  let state = state.handle_key_char!('e')
  let state = state.handle_key_char!('y')
  let state = state.handle_key_char!('\n')
  inspect!(state.ctx.key, content="key")
  inspect!(state.phase, content="Start")
  let section = state.ctx.sections.get(state.ctx.current_section)
  inspect!(section.is_empty(), content="false")
  let value = section.unwrap().get("key")
  inspect!(value, content="Some(Value(\"\"))")
}

///|
test "panic IniParseState::handle_value_char/quote_not_closed_nl" {
  let state = IniParseState::new()
  let state = state.handle_value_char!('\n')
  ignore(state)
}

///|
test "panic IniParseState::handle_value_char/quote_not_closed_comment" {
  let state = IniParseState::new()
  let state = state.handle_value_char!(';')
  ignore(state)
}

///|
test "panic IniParseState::handle_value_char/quote_mismatch_single_double" {
  let state = IniParseState::new()
  let state = state.parse!("[section]\nkey=")
  let state = state.handle_value_char!('"')
  let state = state.handle_value_char!('\'')
  ignore(state)
}

///|
test "panic IniParseState::handle_value_char/quote_mismatch_double_single" {
  let state = IniParseState::new()
  let state = state.parse!("[section]\nkey=")
  let state = state.handle_value_char!('\'')
  let state = state.handle_value_char!('"')
  ignore(state)
}

///|
test "IniParseState::handle_comment/basic" {
  let state = IniParseState::new().parse!("[section]\nkey=value#")
  // Test non-newline characters should keep the state unchanged
  let state = state.handle_comment('a')
  inspect!(state.phase, content="InComment")
  let state = IniParseState::new().parse!("[section]\nkey=value#")
  // Test newline should reset the line
  let state = state.handle_comment('\n')
  inspect!(state.phase, content="Start")
  inspect!(state.ctx.buffer.is_empty(), content="true")
}

///|
test "IniParseState::handle_comment/special_chars" {
  let state = IniParseState::new().parse!("[section]\nkey=value#")
  // Test special characters should not affect the state
  inspect!(state.handle_comment('#').phase, content="InComment")
  inspect!(state.handle_comment(';').phase, content="InComment")
  inspect!(state.handle_comment('=').phase, content="InComment")
  inspect!(state.handle_comment('[').phase, content="InComment")
  inspect!(state.handle_comment(']').phase, content="InComment")
}

///|
test "IniParseState::commit_value/basic" {
  let state = IniParseState::new()
  let state = state.parse!("[section]\nkey=value")
  let state = state.commit_value!()
  inspect!(state.ctx.buffer.is_empty(), content="true")
  // Verify the section exists
  let section = state.ctx.sections.get(Section::NamedSection("section"))
  inspect!(section.is_empty(), content="false")
  // Verify the key exists in the section
  let value = section.unwrap().get("key")
  inspect!(value.is_empty(), content="false")
}

///|
test "panic IniParseState::commit_value/no_section" {
  let state = IniParseState::new()
  state.ctx.buffer.write_string("value")
  ignore(state.commit_value!())
}

///|
test "IniParseState::commit_value/empty_value" {
  let state = IniParseState::new()
  let state = state.parse!("[section]\nkey=")
  let state = state.commit_value!()
  // Verify the section exists
  let section = state.ctx.sections.get(Section::NamedSection("section"))
  inspect!(section.is_empty(), content="false")
  // Verify the key exists in the section with empty value
  let value = section.unwrap().get("key")
  inspect!(value.is_empty(), content="false")
}
