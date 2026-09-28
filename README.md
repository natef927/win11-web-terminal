# ⚡ Win11 Web Terminal

> **极简、原生、开箱即用的 Windows 网页终端方案**  
> 基于 Node.js · ConPTY · xterm.js 构建，零复杂依赖，双击一键即用。

[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?logo=windows&logoColor=white)](https://github.com/natef927/win11-web-terminal)
[![Node.js](https://img.shields.io/badge/Node.js-18%2B%20%7C%2020%20LTS-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Driver](https://img.shields.io/badge/Driver-Windows%20ConPTY-lightgrey)](https://github.com/natef927/win11-web-terminal)

---

## 💡 为什么需要本项目？

在 Windows 运维和跨设备操作场景中，如果想在浏览器中直接获得一个完全原生的命令行，通常面临以下难题：

* **笨重的依赖链**：传统方案通常强制绑定 WSL2、Hyper-V 或 Docker 容器环境，系统开销大。
* **原生 ConPTY 兼容缺陷**：原生单文件工具（如部分旧版 `ttyd.exe`）在最新 Win11 ConPTY 握手阶段容易闪退；而简单的管道模式又无法处理终端色彩、动态窗口大小与光标状态。
* **外部网络与 CDN 风险**：内网离线机房若依赖 unpkg / cdnjs 静态资源，常因网络隔离导致终端页面无法渲染。

**Win11 Web Terminal** 仅需一个经过打磨的批处理脚本，即可自动准备环境、下载驱动并打通前后端动态管道，提供如同本地 Windows Terminal 的流畅交互。

---

## 🏛️ 工作原理与架构
