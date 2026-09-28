@powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%~f0' -replace '^[\\/]+([A-Za-z]:)', '$1';$c=[System.IO.File]::ReadAllLines($p,[System.Text.Encoding]::UTF8); Invoke-Expression (($c | Select-Object -Skip 2) -join [Environment]::NewLine)" & pause & exit /b
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "          Win11 Native Web Terminal Setup              " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

# 1. 自动选择磁盘（优先 D 盘，无 D 盘自动降级到 C 盘）
$installDir = if (Test-Path "D:\") { "D:\web-terminal" } else { "C:\web-terminal" }
Write-Host "[*] Install Path: $installDir" -ForegroundColor Gray

# 2. 检查并自动安装 Node.js 环境
$nodeInstalled = (Get-Command node -ErrorAction SilentlyContinue) -ne$null
if (-not $nodeInstalled) {
    Write-Host "[!] Node.js not detected. Starting auto-installation..." -ForegroundColor Yellow
    $wingetAvailable = (Get-Command winget -ErrorAction SilentlyContinue) -ne$null

    if ($wingetAvailable) {
        Write-Host "[*] Installing Node.js LTS via winget..." -ForegroundColor Cyan
        Start-Process winget -ArgumentList "install --id OpenJS.NodeJS.LTS -e --silent --accept-source-agreements --accept-package-agreements" -Wait
    } else {
        Write-Host "[*] Downloading Node.js MSI from official site..." -ForegroundColor Cyan
        $msiPath = "$env:TEMP\nodejs_installer.msi"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        (New-Object Net.WebClient).DownloadFile("https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi", $msiPath)
        
        Write-Host "[*] Silently installing Node.js..." -ForegroundColor Cyan
        Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait
        Remove-Item -Path $msiPath -Force -ErrorAction SilentlyContinue
    }

    $sysPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $usrPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$sysPath;$usrPath;C:\Program Files\nodejs;$env:APPDATA\npm"

    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Host "[!] Node.js installation finished. Please re-run the script!" -ForegroundColor Yellow
        exit
    }
    Write-Host "[OK] Node.js is ready." -ForegroundColor Green
}

# 3. 部署自检与脚本更新
$isReady = (Test-Path "$installDir\server.js") -and 
           (Test-Path "$installDir\node_modules\node-pty") -and 
           (Test-Path "$installDir\node_modules\@xterm\xterm") -and 
           (Test-Path "$installDir\node_modules\@xterm\addon-fit")

if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}
Set-Location $installDir

if (-not $isReady) {
    Write-Host "[1/5] Installing npm dependencies..." -ForegroundColor Cyan
    if (-not (Test-Path "$installDir\package.json")) {
        npm init -y | Out-Null
    }
    npm install ws @xterm/xterm @xterm/addon-fit node-pty --silent

    Write-Host "[2/5] Writing server.js..." -ForegroundColor Cyan
    $serverCode = @'
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
  <meta charset="utf-8" />
  <title>Win11 Web Terminal</title>
  <link rel="stylesheet" href="/xterm.css" />
  <script src="/xterm.js"></script>
  <script src="/addon-fit.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; background: #0c0c0c; }
    #terminal { width: 100vw; height: 100vh; padding: 4px; }
  </style>
</head>
<body>
  <div id="terminal"></div>
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

    ws.onopen = () => { sendResize(); };
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
      if (e.ctrlKey && e.code === 'KeyV') { return false; }
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
      if (selection && selection.length > 0) { navigator.clipboard.writeText(selection); }
    });

    window.addEventListener('resize', () => { sendResize(); });
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

  ptyProcess.onData((data) => { if (ws.readyState === 1) ws.send(data); });
  ws.on('message', (message) => {
    try {
      const msg = JSON.parse(message.toString());
      if (msg.type === 'input') { ptyProcess.write(msg.data); }
      else if (msg.type === 'resize') { ptyProcess.resize(msg.cols, msg.rows); }
    } catch (e) { ptyProcess.write(message.toString()); }
  });

  ws.on('close', () => ptyProcess.kill());
  ptyProcess.onExit(() => ws.close());
});

server.listen(7681, '0.0.0.0', () => {
  console.log('Web Terminal server ready: http://127.0.0.1:7681');
});
'@
    [System.IO.File]::WriteAllText("$installDir\server.js", $serverCode, [System.Text.Encoding]::UTF8)
}

# 4. 生成或刷新运维脚本（包含后台拉起与自动打开浏览器）
Write-Host "[*] Updating helper scripts & shortcut..." -ForegroundColor Cyan

# start.vbs: 后台启动 node 服务，并自动调起默认浏览器定位到终端
$vbsLines = @(
    'Set WshShell = CreateObject("WScript.Shell")',
    "WshShell.CurrentDirectory = `"$installDir`"",
    'WshShell.Run "node server.js", 0, False',
    'WScript.Sleep 1000',
    'WshShell.Run "http://127.0.0.1:7681"'
)
[System.IO.File]::WriteAllLines("$installDir\start.vbs", $vbsLines, [System.Text.Encoding]::ASCII)

# stop.bat: 一键终止后台 node 进程
$batLines = @(
    '@echo off',
    'chcp 65001 >nul',
    'taskkill /f /im node.exe >nul 2>nul',
    'echo [INFO] Web Terminal service stopped.',
    'pause'
)
[System.IO.File]::WriteAllLines("$installDir\stop.bat", $batLines, [System.Text.Encoding]::ASCII)

# 桌面快捷方式：指向 start.vbs
$wsh = New-Object -ComObject WScript.Shell
$shortcut =$wsh.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\WebTerminal.lnk')
$shortcut.TargetPath = "$installDir\start.vbs"
$shortcut.WorkingDirectory = "$installDir"
$shortcut.Description = "Start Win11 Web Terminal"
$shortcut.Save()

# 5. 立即启动当前服务
Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "          Starting service and opening browser...      " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

Get-Process -Name node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process "wscript.exe" -ArgumentList "`"$installDir\start.vbs`""

Write-Host ""
Write-Host "[OK] Service running in background: http://127.0.0.1:7681" -ForegroundColor Green
Write-Host ""
