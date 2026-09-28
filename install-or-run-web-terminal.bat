@echo off
chcp 65001 >nul
title Win11 Web Terminal 智能安装与启动向导

echo =======================================================
echo          Win11 原生 Web Terminal 管理向导
echo =======================================================
echo.

:: 1. 检查基础环境 (Node.js)
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未检测到 Node.js，请先安装 Node.js 后再运行本脚本！
    echo 下载地址: https://nodejs.org/
    pause
    exit /b
)

set "INSTALL_DIR=D:\web-terminal"

:: 2. 检查是否已经完整安装过
echo [*] 检查本地环境状态...
if exist "%INSTALL_DIR%\server.js" (
    if exist "%INSTALL_DIR%\node_modules\node-pty" (
        if exist "%INSTALL_DIR%\node_modules\@xterm\xterm" (
            if exist "%INSTALL_DIR%\node_modules\@xterm\addon-fit" (
                echo.
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

echo [3/5] 写入服务端核心文件 (server.js - 集成全屏自适应与智能剪贴板)...
powershell -NoProfile -Command ^
"@'
const http = require('http');
const fs = require('fs');
const path = require('path');
const pty = require('node-pty');
const { WebSocketServer } = require('ws');

const server = http.createServer((req, res) => {
  if (req.url === '/xterm.js') {
    const jsPath = path.join(__dirname, 'node_modules', '@xterm', 'xterm', 'lib', 'xterm.js');
    res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
    return fs.createReadStream(jsPath).pipe(res);
  }
  if (req.url === '/xterm.css') {
    const cssPath = path.join(__dirname, 'node_modules', '@xterm', 'xterm', 'css', 'xterm.css');
    res.writeHead(200, { 'Content-Type': 'text/css; charset=utf-8' });
    return fs.createReadStream(cssPath).pipe(res);
  }
  if (req.url === '/addon-fit.js') {
    const fitPath = path.join(__dirname, 'node_modules', '@xterm', 'addon-fit', 'lib', 'addon-fit.js');
    res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
    return fs.createReadStream(fitPath).pipe(res);
  }

  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`<!DOCTYPE html>
<html>
<head>
  <meta charset=\"utf-8\" />
  <title>Win11 Web Terminal</title>
  <link rel=\"stylesheet\" href=\"/xterm.css\" />
  <script src=\"/xterm.js\"></script>
  <script src=\"/addon-fit.js\"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; background: #0c0c0c; }
    #terminal { width: 100vw; height: 100vh; padding: 4px; }
  </style>
</head>
<body>
  <div id=\"terminal\"></div>
  <script>
    const term = new Terminal({
      cursorBlink: true,
      theme: { background: '#0c0c0c', foreground: '#cccccc' },
      fontSize: 16,
      fontFamily: 'Cascadia Mono, Consolas, monospace'
    });

    const fitAddon = new FitAddon.FitAddon();
    term.loadAddon(fitAddon);
    term.open(document.getElementById('terminal'));
    term.focus();

    const ws = new WebSocket(\`ws://\${location.host}\`);

    function sendResize() {
      try {
        fitAddon.fit();
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: 'resize', cols: term.cols, rows: term.rows }));
        }
      } catch (err) {}
    }

    ws.onopen = () => {
      sendResize();
    };

    ws.onmessage = (e) => term.write(e.data);

    term.attachCustomKeyEventHandler((e) => {
      if (e.ctrlKey && e.code === 'KeyC') {
        const selection = term.getSelection();
        if (selection && selection.length > 0) {
          navigator.clipboard.writeText(selection);
          return false;
        }
        return true;
      }
      if (e.ctrlKey && e.code === 'KeyV') {
        return false;
      }
      return true;
    });

    term.onData((data) => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'input', data: data }));
      }
    });

    window.addEventListener('paste', (e) => {
      const clipText = (e.clipboardData || window.clipboardData).getData('text');
      if (clipText && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'input', data: clipText }));
      }
    });

    window.addEventListener('contextmenu', async (e) => {
      e.preventDefault();
      const selection = term.getSelection();
      if (selection && selection.length > 0) {
        await navigator.clipboard.writeText(selection);
        term.clearSelection();
      } else {
        try {
          const text = await navigator.clipboard.readText();
          if (text && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'input', data: text }));
          }
        } catch (err) {}
      }
    });

    window.addEventListener('mouseup', () => {
      const selection = term.getSelection();
      if (selection && selection.length > 0) {
        navigator.clipboard.writeText(selection);
      }
    });

    window.addEventListener('resize', () => {
      sendResize();
    });

    window.addEventListener('click', () => term.focus());
  </script>
</body>
</html>`);
});

const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  const shell = 'powershell.exe';
  const ptyProcess = pty.spawn(shell, [], {
    name: 'xterm-color',
    cols: 100,
    rows: 30,
    cwd: process.env.USERPROFILE,
    env: process.env,
    useConpty: true
  });

  ptyProcess.onData((data) => {
    if (ws.readyState === 1) ws.send(data);
  });

  ws.on('message', (message) => {
    try {
      const msg = JSON.parse(message.toString());
      if (msg.type === 'input') {
        ptyProcess.write(msg.data);
      } else if (msg.type === 'resize') {
        ptyProcess.resize(msg.cols, msg.rows);
      }
    } catch (e) {
      ptyProcess.write(message.toString());
    }
  });

  ws.on('close', () => ptyProcess.kill());
  ptyProcess.onExit(() => ws.close());
});

server.listen(7681, '0.0.0.0', () => {
  console.log('Web Terminal 服务已就绪: http://127.0.0.1:7681');
});
'@ | Out-File -FilePath 'server.js' -Encoding utf8"

echo [4/5] 生成运维辅助脚本 (start.vbs, stop.bat)...
powershell -NoProfile -Command ^
"@'
Set WshShell = CreateObject(\"WScript.Shell\")
WshShell.CurrentDirectory = \"%INSTALL_DIR%\"
WshShell.Run \"node server.js\", 0, False
'@ | Out-File -FilePath 'start.vbs' -Encoding ascii"

powershell -NoProfile -Command ^
"@'
@echo off
chcp 65001 >nul
taskkill /f /im node.exe >nul 2>nul
echo [INFO] 已终止 Node.js 服务。
pause
'@ | Out-File -FilePath 'stop.bat' -Encoding utf8"

echo [5/5] 创建桌面快捷方式...
powershell -NoProfile -Command ^
"$WshShell = New-Object -ComObject WScript.Shell; ^
$Shortcut =$WshShell.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\启动Web终端.lnk'); ^
$Shortcut.TargetPath = '%INSTALL_DIR%\start.vbs'; ^
$Shortcut.WorkingDirectory = '\%INSTALL_DIR\%'; ^$Shortcut.Description = '启动 Win11 Web Terminal'; ^
$Shortcut.Save()"

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