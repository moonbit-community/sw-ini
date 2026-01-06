# 📝 ini: A MoonBit INI Parser

[English](https://github.com/moonbit-community/ini/blob/main/README.md) | [简体中文](https://github.com/moonbit-community/ini/blob/main/README_zh_CN.md)

[![Build Status](https://img.shields.io/github/actions/workflow/status/moonbit-community/ini/check.yaml)](https://github.com/moonbit-community/ini/actions)
[![License](https://img.shields.io/github/license/moonbit-community/ini)](LICENSE)
[![codecov](https://codecov.io/gh/moonbit-community/ini/branch/main/graph/badge.svg)](https://codecov.io/gh/moonbit-community/ini)

**ini** is a high-performance INI parser for MoonBit applications. It provides a simple and efficient way to parse and access INI configuration files with a clean and intuitive API.

🚀 **Key Features**

- 🔍 **INI Parsing** – Parse INI files with comprehensive error handling
- 🛡️ **Type Safety** – Strongly typed access to configuration values
- 🔄 **Case Sensitivity Options** – Configurable case sensitivity for section and key names
- 🎯 **Simple API** – Easy to use with intuitive method names
- 📦 **Zero Dependencies** – Pure MoonBit implementation with no external dependencies

---

## 📥 Installation

```
moon add moonbit-community/ini
```

## **🚀 Usage Guide for `ini`**

ini provides a straightforward way to parse and access INI configuration files in your MoonBit applications.

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

The simplest way to use `ini` is with the `parse` function:

```mbt check
///|
test {
  let config_str =
    #|[server]
    #|host=localhost
    #|port=3000
  let ini = @ini.parse(config_str)
  let host = ini.get(section="server", "host").unwrap()
  inspect(host, content="localhost")
}
```

### **⚙️ Configuration Options**

ini offers configuration options when parsing:

```mbt check
///|
test {
  let content =
    #|[server]
    #|host=localhost
    #|port=3000
    #|[Server]
    #|host=remote

  // Case-sensitive parsing

  let ini = @ini.parse(content, is_case_sensitive=true)
  inspect(ini.get(section="server", "host").unwrap(), content="localhost")
  inspect(ini.get(section="Server", "host").unwrap(), content="remote")

  // Create an empty INI file object

  let ini = @ini.IniFile::new(is_case_sensitive=true)
  ignore(ini)
}
```

---

### **🔄 Value Access**

After parsing, you can access values using various methods:

```mbt check
///|
test {
  let content =
    #|[server]
    #|host=localhost
    #|port=3000
    #|[feature]
    #|foo=true
  let ini = @ini.parse(content)
  let host = ini.get(section="server", "host")
  inspect(
    host,
    content=(
      #|Some("localhost")
    ),
  )
  let foo_enabled = ini.get_bool(section="feature", "foo")
  inspect(foo_enabled, content="Some(true)")
}
```

---


### **🛠️ Full Example**

```mbt check
///|
test {
  let content =
    #|[server]
    #|host=localhost
    #|port=3000
    #|enabled=true
    #|
    #|[database]
    #|url=mysql://localhost/db

  // Parse INI content
  let ini = @ini.parse(content)

  // Access various values
  let host = ini.get(section="server", "host").unwrap()
  let port = ini.get(section="server", "port").unwrap_or("8080")
  let enabled = ini.get_bool(section="server", "enabled").unwrap()
  inspect(
    if enabled {
      "\{host}:\{port}"
    } else {
      ""
    },
    content="localhost:3000",
  )
}
```

## 📜 License

This project is licensed under the Apache-2.0 License. See [LICENSE](https://github.com/moonbit-community/ini/blob/main/LICENSE) for details.

## 📢 Contact & Support

- GitHub Issues: [Report an issue](https://github.com/moonbit-community/ini/issues)

👋 If you like this project, give it a ⭐! Happy coding! 🚀
