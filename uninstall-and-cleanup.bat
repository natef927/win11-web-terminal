@powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=('%~f0' -replace '^[\\/]+([A-Za-z]:)', '$1'); if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Start-Process cmd.exe -Verb RunAs -ArgumentList ('/c ""' + $f + '""'); exit } $lines=[System.IO.File]::ReadAllLines($f,[System.Text.Encoding]::UTF8); Invoke-Expression (($lines | Select-Object -Skip 1) -join [Environment]::NewLine)" & exit /b
# =======================================================
# 下方全部为纯 PowerShell 代码（已获得管理员权限）
# =======================================================

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "       Win11 Web Terminal 环境与依赖彻底清理向导       " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

# 1. 终止后台进程
Write-Host "[1/5] 终止后台服务进程 (node.exe, wscript.exe)..." -ForegroundColor Cyan
Stop-Process -Name node -Force -ErrorAction SilentlyContinue
Stop-Process -Name wscript -Force -ErrorAction SilentlyContinue

# 2. 删除目录与快捷方式
Write-Host "[2/5] 删除部署文件与桌面快捷方式..." -ForegroundColor Cyan
Remove-Item -Path "D:\web-terminal" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\web-terminal" -Recurse -Force -ErrorAction SilentlyContinue

$desktop = [Environment]::GetFolderPath('Desktop')
Remove-Item -Path "$desktop\WebTerminal.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$desktop\启动Web终端.lnk" -Force -ErrorAction SilentlyContinue

# 3. 卸载 Node.js 运行时
Write-Host "[3/5] 正在彻底卸载 Node.js..." -ForegroundColor Cyan
if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget uninstall --id OpenJS.NodeJS.LTS -e --silent 2>$null
    winget uninstall --id OpenJS.NodeJS -e --silent 2>$null
}

$keys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
@((Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue)).ForEach({
    if ($_.DisplayName -like "*Node.js*") {
        if ($_.UninstallString -match '{[A-F0-9-]+}') {
            $guid = $matches[0]
            Write-Host "正在通过 MSI 卸载: $guid" -ForegroundColor Yellow
            Start-Process msiexec.exe -ArgumentList "/x $guid /qn /norestart" -Wait
        }
    }
})

# 4. 删除残留文件与 npm 缓存
Write-Host "[4/5] 清除本地残留文件与 npm 缓存..." -ForegroundColor Cyan
Remove-Item -Path "C:\Program Files\nodejs" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Program Files (x86)\nodejs" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:APPDATA\npm" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:APPDATA\npm-cache" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LOCALAPPDATA\npm-cache" -Recurse -Force -ErrorAction SilentlyContinue

# 5. 清理系统与用户 PATH 变量
Write-Host "[5/5] 从 PATH 环境变量中移除残留项..." -ForegroundColor Cyan
$sysReg = "HKLM:\System\CurrentControlSet\Control\Session Manager\Environment"
$sysPath = (Get-ItemProperty -Path $sysReg -Name Path -ErrorAction SilentlyContinue).Path
if ($sysPath) {
    $cleanSys = ($sysPath -split ';').Where({ $_ -and ($_ -notmatch '(?i)nodejs') }) -join ';'
    Set-ItemProperty -Path $sysReg -Name Path -Value $cleanSys
}

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath) {
    $cleanUser = ($userPath -split ';').Where({ $_ -and ($_ -notmatch '(?i)nodejs') -and ($_ -notmatch '(?i)npm') }) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $cleanUser, "User")
}

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Green
Write-Host "  [OK] 环境已全部清除，系统已恢复至全新纯净初始状态！  " -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "请按任意键退出本窗口..." -ForegroundColor Gray
$null = [Console]::ReadKey($true)
