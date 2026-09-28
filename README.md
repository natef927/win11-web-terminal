# ⚡ Win11 Web Terminal

> **基于 Node.js + Windows ConPTY + xterm.js 的原生轻量 Web 终端一键部署工具**  
> 无需 WSL、无需 Docker、不依赖第三方笨重编译环境，一键在浏览器中获得与原生 Windows Terminal 完全一致的命令行体验。

[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?logo=windows&logoColor=white)](https://github.com/natef927/win11-web-terminal)
[![Node.js](https://img.shields.io/badge/Node.js-18%2B%20%7C%2020%20LTS-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Driver](https://img.shields.io/badge/Driver-Windows%20ConPTY-lightgrey)](https://github.com/natef927/win11-web-terminal)

---

## 📖 项目背景与作用

在 Windows 办公与运维场景下，直接访问本地终端往往受限于坐席位置，而市面上常见的 Web 终端工具存在以下痛点：

1. **WSL / Docker 依赖重**：在纯 Windows 办公机上部署 Linux 容器或子系统过于冗杂，占用数 GB 内存与磁盘空间。
2. **底层 ConPTY 兼容缺陷**：原生 `ttyd.exe` 在新版 Windows 11 下极易在 WebSocket 握手时闪退崩溃；传统 Node.js `child_process.spawn` 管道模式无法支持交互式命令（导致 SSH、密码盲打、Vim 无法正常输入）。
3. **外部网络与 CDN 依赖**：很多开源 Web 终端引用公共 CDN（如 unpkg / cdnjs），在公司内网隔离或网络波动时极易由于脚本加载失败而白屏。

**本项目通过一个轻量级 `.bat` 批处理脚本，全自动完成环境准备、依赖安装、ConPTY 绑定、本地资源托管、双向窗口自适应与开机静默运维配置，提供开箱即用的原生 Web 终端环境。**

---

## 🏛️ 工作原理与架构

整个方案采用轻量三层解耦架构，保证最低开销与最高稳定性：

* **渲染层（Browser Frontend）**：
  * 基于 `@xterm/xterm` 渲染完整控制台视图。
  * 挂载 `@xterm/addon-fit` 动态监控网页与视口变化。
  * 拦截原生剪贴板与右键操作，实现与 Windows 终端完全同步的操作手感。
* **通信与托管层（Node.js Local Server）**：
  * 内置 HTTP 静态文件伺服，直接流式读取本地 `node_modules` 中的 JS/CSS，彻底脱离外部 CDN。
  * 建立 WebSocket 长连接通道，以 JSON 格式双向分发用户输入（Input）与终端尺寸重算（Resize）。
* **驱动层（Windows Native ConPTY）**：
  * 引入 `node-pty` 原生调用 Windows 11 底层 `CreatePseudoConsole` 接口。
  * 完美承载 PowerShell 与 CMD 的所有交互指令，真彩字符、光标控制、密码盲打完全一致。

---

## ✨ 核心特性

* 🚀 **自动化环境就绪**：纯净新电脑一键运行，若检测到缺少 Node.js，脚本自动调用 Windows 原生 `winget` 或官方安装包静默安装并动态刷新 PATH，无需用户手动配置。
* 🖥️ **全屏动态自适应 (Addon-Fit)**：集成 `@xterm/addon-fit`，窗口缩放、分屏或全屏（按 `F11`）时，行列尺寸秒级自动同步给后端 PTY，告别右侧黑边与文本排版错乱。
* 📋 **智能剪贴板交互**：
  * **Ctrl + C**：有选中文本时执行「复制」；无选中文本时执行「中断当前命令 (SIGINT)」。
  * **Ctrl + V**：无缝将系统剪贴板内容注入终端。
  * **鼠标流支持**：鼠标划选文本**自动复制**，鼠标右键单击**智能复制/粘贴**。
* 🔌 **原生命令完美支持**：
  * 完美支持 `ssh` 远程登录软路由、NAS 及 Linux 服务器。
  * 交互式密码输入（盲打无回显）正常响应。
  * 完整支持 `vim`、`nano`、`top`、`htop`、ANSI 24-bit 真彩色高亮。
* 🌐 **完全脱离外部网络 (Zero CDN)**：所有前端库、CSS 样式均由本地服务直接供应，内网完全断网环境下依然稳定可用。
* 🔕 **零窗口后台常驻**：内置 VBScript 静默启动方案，运行后不占用任务栏黑框窗口。
* ⚡ **智能幂等自检**：安装脚本具备环境自检能力，重复运行秒级跳过安装，直接拉起服务。

---

## ⌨️ 智能交互与键位支持

| 操作方式 | 触发行为 | 效果说明 |
| :--- | :--- | :--- |
| **Ctrl + C**（有选中区域） | 📋 复制 | 将选中文本写入系统剪贴板，不触发进程中断 |
| **Ctrl + C**（无选中区域） | 🛑 发送 SIGINT | 中断当前正在运行的命令或前台进程 |
| **Ctrl + V** | 📥 粘贴 | 将系统剪贴板内容直接输出至当前终端 |
| **鼠标划选松手** | 📋 自动复制 | 鼠标选中文本释放瞬间完成复制 |
| **鼠标右键单击** | 📥 智能粘贴 / 复制 | 有选中区域时复制选区；无选区时自动执行粘贴 |
| **调整浏览器窗口大小** | 📐 动态适配 | 自动触发 PTY 尺寸重算，铺满整个浏览器视图 |
| **按 F11 键** | 🖥️ 全屏终端 | 进入无干扰全屏模式，自动拉伸至显示器分辨率 |

---

## 🚀 快速上手使用

### 1. 下载脚本
从本仓库直接下载核心管理脚本：  
👉 [**下载 install-or-run-web-terminal.bat**](./install-or-run-web-terminal.bat)

### 2. 一键运行
直接双击运行 `install-or-run-web-terminal.bat`：
1. 自动检测基础环境，在 `D:\web-terminal` 目录完成初始化并安装依赖。
2. 自动生成服务端代码与后台静默启动/停止脚本。
3. 自动在桌面创建快捷方式 **`启动Web终端`**。
4. 自动在后台启动服务并在浏览器中打开 `http://127.0.0.1:7681`。

> 💡 **二次启动**：后续只需双击桌面的「启动Web终端」快捷方式，或再次运行该 `.bat`，即可秒级拉起，无需重复安装依赖。

---

## 🛠️ 本地运维与目录说明

默认部署位置为 `D:\web-terminal`：

| 文件 / 文件夹 | 功能说明 |
| :--- | :--- |
| **server.js** | 核心服务驱动（静态伺服 + WebSocket + ConPTY 适配） |
| **start.vbs** | 后台静默启动脚本（双击后后台运行，无黑框弹出） |
| **stop.bat** | 一键终止服务脚本（释放 7681 端口占用） |
| **package.json** | 项目依赖定义文件 |
| **node_modules/** | 本地依赖包缓存目录（已加入 `.gitignore` 过滤） |

### 开机自启动设置方法
1. 按键盘 **Win + R** 键，输入 `shell:startup` 回车打开 Windows 自启动文件夹。
2. 将桌面上的 **`启动Web终端`** 快捷方式复制（或移动）进该文件夹即可实现开机自动静默就绪。

---

## 🎯 核心使用场景

* **局域网跨设备接入**：利用同一局域网下的手机、平板、iPad 或另一台轻薄本，直接通过浏览器访问宿主机 IP（例如 `http://192.168.1.100:7681`），即可远程操控 Windows 机器。
* **轻量 SSH 跳板机**：作为办公或家庭网络内网跳板，免去额外客户端，直接在浏览器内通过 `ssh` 登录管理 OpenWrt 软路由、群晖 NAS 或 Linux 物理服务器。
* **极简 PWA 办公体验**：在 Chrome / Edge 中点击地址栏右侧的“安装应用”图标，可将其转化为独立的无边框桌面终端窗口，体验远优于传统 CMD。

---

## 🔒 安全实践与内网穿透建议

> ⚠️ **安全警告**：当前服务默认监听地址为 `0.0.0.0:7681`，无内置用户身份认证机制。

* **局域网安全**：仅建议在受信任的家庭内网或办公专网中使用。
* **严禁公网直连**：**切勿在路由器直接配置 WAN 口 7681 端口转发**，否则任何探测到该端口的人都将获得你的 Windows 控制权。
* **远程安全访问推荐**：
  * **虚拟局域网（推荐）**：搭配 **Tailscale**、**ZeroTier** 等组网工具，分配内部虚拟 IP 进行加密访问。
  * **反向代理鉴权**：若确需挂载到公网域名，请在前端配置 **Nginx / Caddy**，强制启用 **HTTPS** 与 **Basic Auth** 账密认证。

---

## 📄 开源许可证

本项目基于 [MIT License](./LICENSE) 开放源代码，可自由修改、分发及商用。
