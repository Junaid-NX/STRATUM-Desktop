# ============================================================================
#  QGroundControl (STRATUM-Desktop) - Windows Build Environment Check
#  Target tree: v5.0.3+ (build-config.json: Qt 6.10.3, CMake 3.25, MSVC 2022)
#  Run in normal PowerShell:   powershell -ExecutionPolicy Bypass -File .\check-build-env.ps1
# ============================================================================

$ErrorActionPreference = "SilentlyContinue"
$pass = @(); $fail = @(); $warn = @()

function Test-Cmd($name) { (Get-Command $name -ErrorAction SilentlyContinue).Source }

Write-Host "`n=== QGroundControl Windows Build Environment ===`n" -ForegroundColor Cyan

# --- 1. Visual Studio 2022 / MSVC v143 (the REQUIRED compiler) ---------------
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property displayName
    $vsVer = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property catalog_productDisplayVersion
    if ($vs) { $pass += "MSVC C++ toolchain: $vs ($vsVer)" }
    else { $fail += "Visual Studio found but NO C++ workload. Install 'Desktop development with C++'." }
} else {
    $fail += "Visual Studio 2022 / Build Tools NOT found. This is the required compiler (NOT MinGW)."
}

# --- 2. Qt 6.10.x  msvc2022_64 -----------------------------------------------
$qtRoots = @("C:\Qt", "$env:USERPROFILE\Qt", "D:\Qt")
$qtFound = $null
foreach ($root in $qtRoots) {
    if (Test-Path $root) {
        $kit = Get-ChildItem $root -Directory -Filter "6.10.*" -ErrorAction SilentlyContinue |
               ForEach-Object { Join-Path $_.FullName "msvc2022_64\bin\qt-cmake.bat" } |
               Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($kit) { $qtFound = $kit; break }
    }
}
if ($qtFound) { $pass += "Qt 6.10 MSVC kit: $qtFound" }
else { $fail += "Qt 6.10.x msvc2022_64 kit NOT found. Need >=6.10.0 (target 6.10.3). Use Qt Online Installer." }

# --- 3. CMake >= 3.25 --------------------------------------------------------
$cmake = Test-Cmd cmake
if ($cmake) {
    $cv = (cmake --version | Select-Object -First 1) -replace '[^0-9.]',''
    if ([version]$cv -ge [version]"3.25") { $pass += "CMake $cv" }
    else { $fail += "CMake $cv too old (need >= 3.25)." }
} else { $warn += "cmake not on PATH (Qt bundles one; or install standalone)." }

# --- 4. Ninja ----------------------------------------------------------------
if (Test-Cmd ninja) { $pass += "Ninja $(ninja --version)" }
else { $warn += "ninja not on PATH (ships with Qt 'Developer and Designer Tools')." }

# --- 5. Node.js 20 -----------------------------------------------------------
if (Test-Cmd node) {
    $nv = (node --version) -replace 'v',''
    if ([version]$nv -ge [version]"20.0") { $pass += "Node $nv" }
    else { $warn += "Node $nv (.nvmrc pins 20; only needed for docs/tooling)." }
} else { $warn += "Node not found (only needed for docs/aux tooling, not core build)." }

# --- 6. Python 3 -------------------------------------------------------------
if (Test-Cmd python) { $pass += "Python $((python --version 2>&1) -replace 'Python ','')" }
elseif (Test-Cmd python3) { $pass += "Python3 present" }
else { $warn += "Python 3 not found (used by build/deploy scripts)." }

# --- 7. Git ------------------------------------------------------------------
if (Test-Cmd git) { $pass += "Git $((git --version) -replace 'git version ','')" }
else { $fail += "Git not found." }

# --- Report ------------------------------------------------------------------
Write-Host "PASS" -ForegroundColor Green
$pass | ForEach-Object { Write-Host "  [+] $_" -ForegroundColor Green }
if ($warn) { Write-Host "`nWARN" -ForegroundColor Yellow; $warn | ForEach-Object { Write-Host "  [!] $_" -ForegroundColor Yellow } }
if ($fail) { Write-Host "`nBLOCKERS" -ForegroundColor Red; $fail | ForEach-Object { Write-Host "  [X] $_" -ForegroundColor Red } }

Write-Host ""
if ($fail.Count -eq 0) { Write-Host "READY TO BUILD. See BUILD-Windows.md for commands." -ForegroundColor Cyan }
else { Write-Host "Resolve BLOCKERS above before building. See BUILD-Windows.md." -ForegroundColor Cyan }
Write-Host ""
