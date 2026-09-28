@echo off
chcp 65001 >nul
title Win11 Web Terminal 智能安装与启动向导

echo =======================================================
echo          Win11 原生 Web Terminal 管理向导
echo =======================================================
echo.

:: 1. 检查并自动安装 Node.js 环境
where node >nul 2>nul
if %errorlevel% equ 0 goto NODE_READY

echo [提示] 未检测到 Node.js，准备启动自动安装流程...

where winget >nul 2>nul
if %errorlevel% equ 0 (
    echo [*] 检测到 winget，正在静默下载并安装 Node.js LTS 版本...
    winget install --id OpenJS.NodeJS.LTS -e --silent --accept-source-agreements --accept-package-agreements
    goto REFRESH_ENV
)

echo [*] 未检测到 winget，正在通过官方源下载 Node.js 安装包...
set "NODE_MSI=%TEMP%\nodejs_installer.msi"
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi', '%NODE_MSI%')"

if not exist "%NODE_MSI%" (
    echo [错误] 自动下载 Node.js 失败，请检查网络或前往 https://nodejs.org/ 手动安装！
    pause
    exit /b
)

echo [*] 正在执行 Node.js 静默安装 (可能需要 30-60 秒)...
msiexec /i "%NODE_MSI%" /qn /norestart
del "%NODE_MSI%" >nul 2>nul

:REFRESH_ENV
for /f "tokens=2*" %%a in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USER_PATH=%%b"
set "PATH=%SYS_PATH%;%USER_PATH%;C:\Program Files\nodejs;%APPDATA%\npm"

where node >nul 2>nul
if %errorlevel% neq 0 (
    echo.
    echo [提示] Node.js 已安装完成，但由于系统环境变量生效延迟，请关闭此窗口并重新运行本脚本！
    pause
    exit /b
)
echo [成功] Node.js 运行环境就绪！

:NODE_READY
set "INSTALL_DIR=D:\web-terminal"

:: 2. 检查是否已经完整安装过
echo [*] 检查本地环境状态...
if exist "%INSTALL_DIR%\server.js" (
    if exist "%INSTALL_DIR%\node_modules\node-pty" (
        if exist "%INSTALL_DIR%\node_modules\@xterm\xterm" (
            if exist "%INSTALL_DIR%\node_modules\@xterm\addon-fit" (
                echo [提示] 检测到已存在完整部署: %INSTALL_DIR%
                echo [提示] 正在跳过重复安装流程，准备直接启动服务...
                goto LAUNCH_SERVICE
            )
        )
    )
)

:: 3. 首次安装/补充安装流程
echo.
echo [1/5] 准备工作目录: %INSTALL_DIR%
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
cd /d "%INSTALL_DIR%"

echo [2/5] 正在安装必要依赖模块 (包含窗口自适应插件，耗时约 10-30 秒)...
if not exist "package.json" (
    call npm init -y >nul
)
call npm install ws @xterm/xterm @xterm/addon-fit node-pty --silent
echo 依赖安装完成。

echo [3/5] 写入服务端核心文件 (server.js)...
:: 利用临时 PowerShell 脚本写出服务端代码，100% 避免 CMD 管道符与多行换行截断
set "GEN_PS1=%TEMP%\gen_server.ps1"
(
echo $serverCode = @'
echo const http = require('http'^);
echo const fs = require('fs'^);
echo const path = require('path'^);
echo const pty = require('node-pty'^);
echo const { WebSocketServer } = require('ws'^);
echo.
echo const server = http.createServer((req, res^) =^> {
echo   if (req.url === '/xterm.js'^) {
echo     const jsPath = path.join(__dirname, 'node_modules', '@xterm', 'xterm', 'lib', 'xterm.js'^);
echo     res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' }^);
echo     return fs.createReadStream(jsPath^).pipe(res^);
echo   }
echo   if (req.url === '/xterm.css'^) {
echo     const cssPath = path.join(__dirname, 'node_modules', '@xterm', 'xterm', 'css', 'xterm.css'^);
echo     res.writeHead(200, { 'Content-Type': 'text/css; charset=utf-8' }^);
echo     return fs.createReadStream(cssPath^).pipe(res^);
echo   }
echo   if (req.url === '/addon-fit.js'^) {
echo     const fitPath = path.join(__dirname, 'node_modules', '@xterm', 'addon-fit', 'lib', 'addon-fit.js'^);
echo     res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' }^);
echo     return fs.createReadStream(fitPath^).pipe(res^);
echo   }
echo.
echo   res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' }^);
echo   res.end(`^<!DOCTYPE html^>
echo ^<html^>
echo ^<head^>
echo   ^<meta charset="utf-8" /^>
echo   ^<title^>Win11 Web Terminal^</title^>
echo   ^<link rel="stylesheet" href="/xterm.css" /^>
echo   ^<script src="/xterm.js"^>^</script^>
echo   ^<script src="/addon-fit.js"^>^</script^>
echo   ^<style^>
echo     * { margin: 0; padding: 0; box-sizing: border-box; }
echo     html, body { width: 100%%; height: 100%%; overflow: hidden; background: #0c0c0c; }
echo     #terminal { width: 100vw; height: 100vh; padding: 4px; }
echo   ^</style^>
echo ^</head^>
echo ^<body^>
echo   ^<div id="terminal"^>^</div^>
echo   ^<script^>
echo     const term = new Terminal({
echo       cursorBlink: true,
echo       theme: { background: '#0c0c0c', foreground: '#cccccc' },
echo       fontSize: 16,
echo       fontFamily: 'Cascadia Mono, Consolas, monospace'
echo     }^);
echo.
echo     const fitAddon = new FitAddon.FitAddon(^);
echo     term.loadAddon(fitAddon^);
echo     term.open(document.getElementById('terminal'^)^);
echo     term.focus(^);
echo.
echo     const ws = new WebSocket(`ws://${location.host}`^);
echo.
echo     function sendResize(^) {
echo       try {
echo         fitAddon.fit(^);
echo         if (ws.readyState === WebSocket.OPEN^) {
echo           ws.send(JSON.stringify({ type: 'resize', cols: term.cols, rows: term.rows }^)^);
echo         }
echo       } catch (err^) {}
echo     }
echo.
echo     ws.onopen = (^) =^> { sendResize(^); };
echo     ws.onmessage = (e^) =^> term.write(e.data^);
echo.
echo     term.attachCustomKeyEventHandler((e^) =^> {
echo       if (e.ctrlKey ^&^& e.code === 'KeyC'^) {
echo         const selection = term.getSelection(^);
echo         if (selection ^&^& selection.length ^> 0^) {
echo           navigator.clipboard.writeText(selection^);
echo           return false;
echo         }
echo         return true;
echo       }
echo       if (e.ctrlKey ^&^& e.code === 'KeyV'^) { return false; }
echo       return true;
echo     }^);
echo.
echo     term.onData((data^) =^> {
echo       if (ws.readyState === WebSocket.OPEN^) {
echo         ws.send(JSON.stringify({ type: 'input', data: data }^)^);
echo       }
echo     }^);
echo.
echo     window.addEventListener('paste', (e^) =^> {
echo       const clipText = (e.clipboardData ^|^| window.clipboardData^).getData('text'^);
echo       if (clipText ^&^& ws.readyState === WebSocket.OPEN^) {
echo         ws.send(JSON.stringify({ type: 'input', data: clipText }^)^);
echo       }
echo     }^);
echo.
echo     window.addEventListener('contextmenu', async (e^) =^> {
echo       e.preventDefault(^);
echo       const selection = term.getSelection(^);
echo       if (selection ^&^& selection.length ^> 0^) {
echo         await navigator.clipboard.writeText(selection^);
echo         term.clearSelection(^);
echo       } else {
echo         try {
echo           const text = await navigator.clipboard.readText(^);
echo           if (text ^&^& ws.readyState === WebSocket.OPEN^) {
echo             ws.send(JSON.stringify({ type: 'input', data: text }^)^);
echo           }
echo         } catch (err^) {}
echo       }
echo     }^);
echo.
echo     window.addEventListener('mouseup', (^) =^> {
echo       const selection = term.getSelection(^);
echo       if (selection ^&^& selection.length ^> 0^) { navigator.clipboard.writeText(selection^); }
echo     }^);
echo.
echo     window.addEventListener('resize', (^) =^> { sendResize(^); }^);
echo     window.addEventListener('click', (^) =^> term.focus(^)^);
echo   ^</script^>
echo ^</body^>
echo ^</html^>`^);
echo }^);
echo.
echo const wss = new WebSocketServer({ server }^);
echo.
echo wss.on('connection', (ws^) =^> {
echo   const shell = 'powershell.exe';
echo   const ptyProcess = pty.spawn(shell, [], {
echo     name: 'xterm-color',
echo     cols: 100,
echo     rows: 30,
echo     cwd: process.env.USERPROFILE,
echo     env: process.env,
echo     useConpty: true
echo   }^);
echo.
echo   ptyProcess.onData((data^) =^> { if (ws.readyState === 1^) ws.send(data^); }^);
echo   ws.on('message', (message^) =^> {
echo     try {
echo       const msg = JSON.parse(message.toString(^)^);
echo       if (msg.type === 'input'^) { ptyProcess.write(msg.data^); }
echo       else if (msg.type === 'resize'^) { ptyProcess.resize(msg.cols, msg.rows^); }
echo     } catch (e^) { ptyProcess.write(message.toString(^)^); }
echo   }^);
echo.
echo   ws.on('close', (^) =^> ptyProcess.kill(^)^);
echo   ptyProcess.onExit((^) =^> ws.close(^)^);
echo }^);
echo.
echo server.listen(7681, '0.0.0.0', (^) =^> {
echo   console.log('Web Terminal 服务已就绪: http://127.0.0.1:7681'^);
echo }^);
echo '@
echo [System.IO.File]::WriteAllText('D:\web-terminal\server.js', $serverCode, [System.Text.Encoding]::UTF8^)
) > "%GEN_PS1%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%GEN_PS1%"
del "%GEN_PS1%" >nul 2>nul
echo 服务端代码写入完成。

echo [4/5] 生成运维辅助脚本 (start.vbs, stop.bat)...
(
echo Set WshShell = CreateObject("WScript.Shell"^)
echo WshShell.CurrentDirectory = "%INSTALL_DIR%"
echo WshShell.Run "node server.js", 0, False
) > start.vbs

(
echo @echo off
echo chcp 65001 ^>nul
echo taskkill /f /im node.exe ^>nul 2^>nul
echo [INFO] 已终止 Node.js 服务。
echo pause
) > stop.bat

echo [5/5] 创建桌面快捷方式...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\启动Web终端.lnk'); $s.TargetPath = '%INSTALL_DIR%\start.vbs'; $s.WorkingDirectory = '\%INSTALL_DIR\%';$s.Save()"

:LAUNCH_SERVICE
echo.
echo =======================================================
echo          正在启动服务并打开浏览器...
echo =======================================================

taskkill /f /im node.exe >nul 2>nul
wscript.exe "%INSTALL_DIR%\start.vbs"

timeout /t 2 >nul
start http://127.0.0.1:7681

echo.
echo 服务已在后台就绪！
echo 访问地址: http://127.0.0.1:7681
echo.
timeout /t 3 >nul
exit
