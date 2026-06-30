# ============================================================================
#  STRATUM-Desktop - Local Windows Build Toolchain Installer (CLI)
#
#  Installs the SAME toolchain GitHub Actions uses (see .github/workflows/
#  ci-build.yml and BUILD-Windows.md):
#     MSVC 2022 (v143) + Windows SDK   via winget (VS 2022 Build Tools)
#     CMake (>=3.25), Ninja, Git, Python  via winget
#     Qt 6.10.3 win64_msvc2022_64 + modules  via aqtinstall (the CLI engine
#                                             behind CI's install-qt-action)
#
#  RUN AS ADMINISTRATOR:
#     powershell -ExecutionPolicy Bypass -File .\install-toolchain.ps1
#
#  GStreamer (video streaming) is OPTIONAL and intentionally skipped here.
#  Pass -WithGStreamer to include it. Skip it for your first build.
# ============================================================================

param(
    [switch]$WithGStreamer
)

$ErrorActionPreference = "Stop"

# --- Versions: keep aligned with .github/workflows/ci-build.yml --------------
$QtVersion = "6.10.3"
$QtArch    = "win64_msvc2022_64"
$QtRoot    = "C:\Qt"                 # check-build-env.ps1 looks here
$QtModules = @(
    "qtgraphs","qtlocation","qtpositioning","qtspeech","qtmultimedia",
    "qtserialport","qtimageformats","qtshadertools","qtconnectivity",
    "qtquick3d","qtsensors","qtscxml","qtwebsockets","qthttpserver"
)

function Section($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }

# --- 0. Sanity: winget present ----------------------------------------------
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
}

# --- 1. MSVC 2022 Build Tools (v143) + Windows SDK ---------------------------
#   This is the ONLY supported Windows compiler for this tree. NOT MinGW.
Section "Visual Studio 2022 Build Tools (MSVC v143 + Windows SDK)"
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-source-agreements --accept-package-agreements `
    --override "--passive --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended"

# --- 2. Build tools: CMake, Ninja, Git, Python ------------------------------
Section "CMake, Ninja, Git, Python"
winget install --id Kitware.CMake          -e --accept-source-agreements --accept-package-agreements
winget install --id Ninja-build.Ninja      -e --accept-source-agreements --accept-package-agreements
winget install --id Git.Git                -e --accept-source-agreements --accept-package-agreements
winget install --id Python.Python.3.12     -e --accept-source-agreements --accept-package-agreements

# Refresh PATH in this session so python/pip resolve without a new shell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")

# --- 3. Qt 6.10.3 via aqtinstall (CLI) --------------------------------------
Section "Qt $QtVersion ($QtArch) via aqtinstall"
python -m pip install --upgrade pip aqtinstall

# aqt install-qt <host> <target> <version> <arch> -O <dir> -m <modules...>
$aqtArgs = @("-m","aqt","install-qt","windows","desktop",$QtVersion,$QtArch,"-O",$QtRoot) + @("-m") + $QtModules
& python @aqtArgs

# --- 4. GStreamer (optional) -------------------------------------------------
if ($WithGStreamer) {
    Section "GStreamer 1.28.x MSVC x64 (runtime + devel)"
    # winget ships the MSVC x64 variant; both packages are required to LINK.
    winget install --id GStreamer.GStreamer            -e --accept-source-agreements --accept-package-agreements
    winget install --id GStreamer.GStreamer.Development -e --accept-source-agreements --accept-package-agreements
    Write-Host "If winget pulled a non-MSVC build, install the *MSVC x64* runtime+devel .msi from gstreamer.freedesktop.org instead." -ForegroundColor Yellow
} else {
    Write-Host "`nSkipping GStreamer (video streaming). Re-run with -WithGStreamer to add it." -ForegroundColor DarkGray
}

# --- 5. Done -----------------------------------------------------------------
Section "Toolchain install complete"
Write-Host "Qt kit expected at: $QtRoot\$QtVersion\msvc2022_64" -ForegroundColor Green
Write-Host @"

NEXT STEPS (open a NEW shell so PATH refreshes):
  1. Verify:   powershell -ExecutionPolicy Bypass -File .\check-build-env.ps1
  2. Open 'Developer PowerShell for VS 2022', OR in any shell run:
       & "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
  3. Build (from BUILD-Windows.md):
       cd qgroundcontrol
       `$QtKit = "$QtRoot\$QtVersion\msvc2022_64"
       & "`$QtKit\bin\qt-cmake.bat" -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DQGC_BUILD_TESTING=OFF
       cmake --build build --parallel
"@ -ForegroundColor Green
