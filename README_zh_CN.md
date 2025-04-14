# 📝 sw-ini: MoonBit INI 解析器

[English](https://github.com/moonbit-community/sw-ini/blob/main/README.md) | [简体中文](https://github.com/moonbit-community/sw-ini/blob/main/README_zh_CN.md)

[![Build Status](https://img.shields.io/github/actions/workflow/status/moonbit-community/sw-ini/check.yaml)](https://github.com/moonbit-community/sw-ini/actions)
[![License](https://img.shields.io/github/license/moonbit-community/sw-ini)](LICENSE)
[![codecov](https://codecov.io/gh/moonbit-community/sw-ini/branch/main/graph/badge.svg)](https://codecov.io/gh/moonbit-community/sw-ini)

**sw-ini** 是一个用于 MoonBit 应用程序的高性能 INI 解析器。它提供了一种简单而高效的方式来解析和访问 INI 配置文件，具有清晰直观的 API。

🚀 **主要特性**

- 🔍 **INI 解析** – 解析 INI 文件，具有全面的错误处理
- 🛡️ **类型安全** – 对配置值进行强类型访问
- 🔄 **大小写敏感选项** – 可配置的节和键名大小写敏感性
- 🎯 **简单 API** – 直观的方法名称，易于使用
- 📦 **零依赖** – 纯 MoonBit 实现，无外部依赖

---

## 📥 安装

```
moon add ShellWen/sw_ini
```

## **🚀 `sw-ini` 使用指南**

sw-ini 提供了在 MoonBit 应用程序中解析和访问 INI 配置文件的简单方法。

---

### **📝 什么是 INI 文件？**

*INI 文件*是一种由节和键值对组成的配置文件格式：

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

### **🔍 基本用法**

使用 `sw-ini` 最简单的方法是使用 `parse` 函数：

```moonbit
fn main {
  let config_str = "[server]\nhost=localhost\nport=3000"
  let ini = @sw_ini.parse!(config_str)
  let host = ini.get(section="server", "host").unwrap()
  println("host=\{host}")
}
```

### **⚙️ 配置选项**

sw-ini 在解析时提供配置选项：

```moonbit
// 大小写敏感解析
let ini = @sw_ini.parse!(content, is_case_sensitive=true)

// 创建空的 INI 文件对象
let ini = @sw_ini.IniFile::new(is_case_sensitive=true)
```

---

### **🔄 值访问**

解析后，您可以使用各种方法访问值：

```moonbit
let ini = @sw_ini.parse!(content)

// 获取字符串值（可选节）
let host = ini.get(section="server", "host")

// 获取布尔值
let enabled = ini.get_bool(section="feature", "enabled")

// 使用默认节（全局）获取
let global_value = ini.get("global_key")
```

---

### **⚠️ 错误处理**

sw-ini 使用 MoonBit 的 `Result` 类型进行错误处理：

```moonbit
match @sw_ini.parse?(content) {
  Ok(ini) =>
    // 使用 INI 文件
    println("解析成功")
  Err(e) =>
    // 处理解析错误
    println("解析 INI 文件时出错")
}
```

---

### **🛠️ 完整示例**

```moonbit
fn main {
  let content = #|[server]
                #|host=localhost
                #|port=3000
                #|enabled=true
                #|
                #|[database]
                #|url=mysql://localhost/db

  // 解析 INI 内容
  let ini = @sw_ini.parse!(content)

  // 访问各种值
  let host = ini.get(section="server", "host").unwrap()
  let port = ini.get(section="server", "port").or("8080")
  let enabled = ini.get_bool(section="server", "enabled").unwrap()

  // 在您的应用程序中使用值
  if enabled {
    println("服务器运行在 \{host}:\{port}")
  }
}
```

## 📜 许可证

本项目根据 Apache-2.0 许可证获得许可。 有关详细信息，请参见 [LICENSE](https://github.com/moonbit-community/sw-ini/blob/main/LICENSE)。

## 📢 联系方式 & 支持

- GitHub Issues: [报告问题](https://github.com/moonbit-community/sw-ini/issues)

👋 如果你喜欢这个项目，给它一个 ⭐! 祝你编码愉快! 🚀
