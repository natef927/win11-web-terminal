@powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%~f0' -replace '^[\\/]+([A-Za-z]:)', '$1'; $c=[System.IO.File]::ReadAllLines($p,[System.Text.Encoding]::UTF8); Invoke-Expression (($c | Select-Object -Skip 2) -join [Environment]::NewLine)" & pause & exit /b
# 检查并自动提升至管理员权限（卸载 Node 及修改系统 PATH 必需）
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[*] 正在请求管理员权限以彻底清理系统环境..." -ForegroundColor Yellow
    $p = $MyInvocation.MyCommand.Path
    if (-not $p) { $p = ($args[0] -replace '^[\\/]+([A-Za-z]:)', '$1') }
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"`$p = '$p' -replace '^[\\/]+([A-Za-z]:)', '`$1'; `$c=[System.IO.File]::ReadAllLines(`$p,[System.Text.Encoding]::UTF8); Invoke-Expression ((`$c | Select-Object -Skip 2) -join [Environment]::NewLine)`""
    exit
}

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "       Win11 Web Terminal 环境与依赖彻底清理向导       " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

# 1. 终止正在运行的后台服务与进程
Write-Host "[1/5] 终止后台服务进程 (node.exe, wscript.exe)..." -ForegroundColor Cyan
Stop-Process -Name node -Force -ErrorAction SilentlyContinue
Stop-Process -Name wscript -Force -ErrorAction SilentlyContinue

# 2. 清理部署目录与桌面快捷方式
Write-Host "[2/5] 删除部署文件与桌面快捷方式..." -ForegroundColor Cyan
Remove-Item -Path "D:\web-terminal" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\web-terminal" -Recurse -Force -ErrorAction SilentlyContinue

$desktop = [Environment]::GetFolderPath('Desktop')
Remove-Item -Path "$desktop\WebTerminal.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$desktop\启动Web终端.lnk" -Force -ErrorAction SilentlyContinue

# 3. 卸载 Node.js 运行时
Write-Host "[3/5] 正在彻底卸载 Node.js..." -ForegroundColor Cyan
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
    winget uninstall --id OpenJS.NodeJS.LTS -e --silent 2>$null
    winget uninstall --id OpenJS.NodeJS -e --silent 2>$null
}

# 注册表 MSI 静默卸载保底
$uninstallKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
Get-ItemProperty $uninstallKeys -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -like "*Node.js*" } | 
    ForEach-Object {
        $uninstallStr =$_.UninstallString
        if ($uninstallStr -match '{[A-F0-9-]+}') {
            $guid =$matches[0]
            Write-Host "正在通过 MSI 清除 Node.js: $guid" -ForegroundColor Yellow
            Start-Process msiexec.exe -ArgumentList "/x $guid /qn /norestart" -Wait
        }
    }

# 4. 删除残留文件夹与 npm 缓存
Write-Host "[4/5] 清除本地残留文件与 npm 缓存..." -ForegroundColor Cyan
Remove-Item -Path "C:\Program Files\nodejs" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Program Files (x86)\nodejs" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:APPDATA\npm" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:APPDATA\npm-cache" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LOCALAPPDATA\npm-cache" -Recurse -Force -ErrorAction SilentlyContinue

# 5. 从系统和用户 PATH 环境变量中剔除残留项
Write-Host "[5/5] 从系统 PATH 环境变量中移除残留项..." -ForegroundColor Cyan
$regSys = "HKLM:\System\CurrentControlSet\Control\Session Manager\Environment"
$sysPath = (Get-ItemProperty -Path$regSys -Name Path -ErrorAction SilentlyContinue).Path
if ($sysPath) {
    $newSysPath = ($sysPath -split ';' | Where-Object { $_ -notlike "*nodejs*" -and $_.Trim() -ne "" }) -join ';'
    Set-ItemProperty -Path $regSys -Name Path -Value$newSysPath
}

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath) {$newUserPath = ($userPath -split ';' \vert{} Where-Object {$_ -notlike "*npm*" -and $_ -notlike "*nodejs*" -and $_.Trim() -ne "" }) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
}

Write-Host ""
Write-Host "[OK] 系统已恢复纯净初始状态，所有组件已彻底清除！" -ForegroundColor Green
Write-Host "你可以直接双击运行 install-or-run-web-terminal.bat 测试完整全新安装流程。" -ForegroundColor Gray
Write-Host ""