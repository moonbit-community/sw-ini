# 📝 sw-ini: A MoonBit INI Parser

[English](https://github.com/moonbit-community/sw-ini/blob/main/README.md) | [简体中文](https://github.com/moonbit-community/sw-ini/blob/main/README_zh_CN.md)

[![Build Status](https://img.shields.io/github/actions/workflow/status/moonbit-community/sw-ini/check.yaml)](https://github.com/moonbit-community/sw-ini/actions)
[![License](https://img.shields.io/github/license/moonbit-community/sw-ini)](LICENSE)
[![codecov](https://codecov.io/gh/moonbit-community/sw-ini/branch/main/graph/badge.svg)](https://codecov.io/gh/moonbit-community/sw-ini)

**sw-ini** is a high-performance INI parser for MoonBit applications. It provides a simple and efficient way to parse and access INI configuration files with a clean and intuitive API.

🚀 **Key Features**

- 🔍 **INI Parsing** – Parse INI files with comprehensive error handling
- 🛡️ **Type Safety** – Strongly typed access to configuration values
- 🔄 **Case Sensitivity Options** – Configurable case sensitivity for section and key names
- 🎯 **Simple API** – Easy to use with intuitive method names
- 📦 **Zero Dependencies** – Pure MoonBit implementation with no external dependencies

---

## 📥 Installation

```
moon add ShellWen/sw_ini
```

## **🚀 Usage Guide for `sw-ini`**

sw-ini provides a straightforward way to parse and access INI configuration files in your MoonBit applications.

---

### **📝 What is an INI File?**

An _INI file_ is a configuration file format that consists of sections and key-value pairs:

_config.ini_

```ini
[server]
host=localhost
port=3000

[database]
url=mysql://user:pass@localhost/dbname
max_connections=100
```

---

### **🔍 Basic Usage**

The simplest way to use `sw-ini` is with the `parse` function:

```moonbit
fn main {
  let config_str = "[server]\nhost=localhost\nport=3000"
  let ini = @sw_ini.parse!(config_str)
  let host = ini.get(section="server", "host").unwrap()
  println("host=\{host}")
}
```

### **⚙️ Configuration Options**

sw-ini offers configuration options when parsing:

```moonbit
// Case-sensitive parsing
let ini = @sw_ini.parse!(content, is_case_sensitive=true)

// Create an empty INI file object
let ini = @sw_ini.IniFile::new(is_case_sensitive=true)
```

---

### **🔄 Value Access**

After parsing, you can access values using various methods:

```moonbit
let ini = @sw_ini.parse!(content)

// Get string value (with optional section)
let host = ini.get(section="server", "host")

// Get boolean value
let enabled = ini.get_bool(section="feature", "enabled")

// Get with default section (global)
let global_value = ini.get("global_key")
```

---

### **⚠️ Error Handling**

sw-ini uses MoonBit's `Result` type for error handling:

```moonbit
match @sw_ini.parse?(content) {
  Ok(ini) =>
    // Use the INI file
    println("Parsed successfully")
  Err(e) =>
    // Handle parse error
    println("Error parsing INI file")
}
```

---

### **🛠️ Full Example**

```moonbit
fn main {
  let content = #|[server]
                #|host=localhost
                #|port=3000
                #|enabled=true
                #|
                #|[database]
                #|url=mysql://localhost/db

  // Parse INI content
  let ini = @sw_ini.parse!(content)

  // Access various values
  let host = ini.get(section="server", "host").unwrap()
  let port = ini.get(section="server", "port").or("8080")
  let enabled = ini.get_bool(section="server", "enabled").unwrap()

  // Use values in your application
  if enabled {
    println("Server running at \{host}:\{port}")
  }
}
```

## 📜 License

This project is licensed under the Apache-2.0 License. See [LICENSE](https://github.com/moonbit-community/sw-ini/blob/main/LICENSE) for details.

## 📢 Contact & Support

- GitHub Issues: [Report an issue](https://github.com/moonbit-community/sw-ini/issues)

👋 If you like this project, give it a ⭐! Happy coding! 🚀
