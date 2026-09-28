## 🧱 技术演进与底层踩坑实录 (Technical Challenges & Evolution)

本项目追求**单文件、双击即用、零前置依赖**的极致便携体验。但在适配多样化 Windows 环境（不同盘符分布、无开发环境的新机、老旧系统组件）的过程中，遭遇并攻克了数个经典的 Windows 脚本底层陷阱：

### 1. CMD 字符集截断与转义崩溃 (Escaping & Redirection Collision)
* **痛点**：在 `.bat` 中直接内嵌 Node.js 服务端代码（含 HTML 标签、JavaScript 模板字符串及管道符号），批处理预解析器会将 `<`、`>` 强行识别为输出重定向符，导致语法当场崩溃，抛出 `'const'`、`'<!DOCTYPE html>' 不是内部命令` 等报错。
* **解决**：淘汰在 CMD 环境下拼接复杂多行文本的做法，改用 **Batch + PowerShell Polyglot（双语混编架构）**，将真正的执行载荷交由 PowerShell 引擎在内存中安全解析。

### 2. Linux 与 Windows 换行符错位 (LF vs. CRLF Offset Glitch)
* **痛点**：脚本在跨平台 Git 提交或从网页下载时，容易被转换为 Linux 换行符（`LF`）。Windows `cmd.exe` 底层按 2 字节（`CRLF`）计算代码行偏移量，遇到 `LF` 会发生**逐行字节向前错位**，硬生生吞掉行首命令（例如将 `$lines` 截成 `ines`、`Write-Host` 截成 `ite-Host`）。
* **解决**：在 `.bat` 的**第 1 行直接完成 PowerShell 调起并执行 `& exit /b`**。CMD 仅读取第 0 偏移处的第 1 行便立即退出会话，永远不会向下扫描多行代码，从机制上彻底免疫换行符差异。

### 3. GBK / ANSI 默认编码吃字符 (Encoding Corruption)
* **痛点**：Windows PowerShell 5.1 默认以系统本地代码页（ANSI/GBK）读取文件。无 BOM 的 UTF-8 中文字符和全角标点常被拆解为错乱的单字节，意外吞噬脚本中的闭合双引号 `"` 或括号 `)`，引发语法解析雪崩。
* **解决**：第 1 行通过指定 `[System.Text.Encoding]::UTF8` 从内存流直接读取脚本内容，并将控制台输出统一规范为纯 ASCII 标识，杜绝多字节字符错乱。

### 4. 根目录与相对路径解析缺陷 (Root Drive Path Bug)
* **痛点**：用户在盘符根目录（如 `D:\>`）下使用 `.\` 相对路径运行脚本时，CMD 的 `%~f0` 解析会在盘符前错误拼接反斜杠（形如 `\D:\...`），导致 .NET 底层 IO 抛出 `NotSupportedException (不支持给定路径的格式)`。
* **解决**：在路径传递给运行时前，内置正则自清洗过滤器（`-replace '^[\\/]+([A-Za-z]:)', '$1'`），自动校正根目录路径异化。

### 5. 单分区与环境缺失兼容 (Single-Partition & Dynamic Recovery)
* **痛点**：部分新装机系统仅有单 `C:` 盘无 `D:` 盘，写死路径会导致直接闪退；此外纯净机器未预装 Node.js 环境。
* **解决**：脚本内置盘符探测机制（动态在 `D:` 与 `C:` 之间无缝切换），并提供 `winget` 与官方 MSI 静默下载的双保底机制，实现真正意义上的“任意纯净机器一键部署”。

---

### 💡 附：从零重新测试（环境彻底清理脚本）
如果需要测试从未安装 Node.js 的全纯净环境，可以使用配套的一键清理脚本：  
👉 [**下载 uninstall-and-cleanup.bat**](./uninstall-and-cleanup.bat)

该脚本会自动请求管理员权限，彻底终止常驻进程、移除 `web-terminal` 部署文件夹、卸载 Node.js 运行时，并清理掉注册表与 PATH 环境变量中的残留项。
