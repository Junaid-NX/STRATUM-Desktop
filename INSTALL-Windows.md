# Windows Toolchain Install — STRATUM-Desktop / QGroundControl

Your environment check left **two blockers** (MSVC 2022, Qt 6.10 kit) and two warnings
(CMake, Ninja). Both warnings are resolved *by the Qt installer*, so this reduces to
**two installs, in this order**:

> **1. MSVC 2022 first → 2. Qt 6.10.3 second.**
> Qt's MSVC kit is a binding to a compiler. Install it before the compiler exists and the
> kit resolves to nothing. Order is the decision.

Budget ~**40–50 GB** of disk and a good network connection.

---

## STEP 1 — Microsoft C++ compiler (MSVC v143)

You only need the **Build Tools** (no IDE) to compile QGC. If you also want the Visual
Studio IDE, install *Visual Studio 2022 Community* instead — same workload selection.

1. Download **Build Tools for Visual Studio 2022**:
   <https://aka.ms/vs/17/release/vs_BuildTools.exe>
2. Run it. In the **Workloads** tab, tick:
   - ☑ **Desktop development with C++**
3. In the right-hand **Installation details** pane, confirm these are checked (they are by
   default under that workload):
   - ☑ **MSVC v143 — VS 2022 C++ x64/x86 build tools (latest)**
   - ☑ **Windows 11 SDK** (latest) — or Windows 10 SDK if on Win10
   - ☑ **C++ CMake tools for Windows**  *(bonus: also installs CMake + Ninja)*
4. Click **Install**. ~7–10 GB.
5. Reboot if prompted.

After this, a **"Developer PowerShell for VS 2022"** entry appears in the Start menu — that
is the shell you build from later.

---

## STEP 2 — Qt 6.10.3 (MSVC 2022 64-bit kit)

1. Create a free **Qt account**: <https://login.qt.io/register> (open-source use requires it).
2. Download the **Qt Online Installer**:
   <https://www.qt.io/download-qt-installer-oss>
3. Run it, sign in, accept the open-source terms.
4. At **Installation Folder**, keep `C:\Qt` (the checker looks there).
   Choose **Custom installation**.
5. Expand **Qt → Qt 6.10.3** and tick:
   - ☑ **MSVC 2022 64-bit**   ← the kit. Do **NOT** pick MinGW.
6. Under **Qt 6.10.3 → Additional Libraries**, tick every module this tree requires:
   - ☑ Qt Multimedia
   - ☑ Qt Positioning
   - ☑ Qt Location
   - ☑ Qt Quick 3D
   - ☑ Qt Sensors
   - ☑ Qt Connectivity
   - ☑ Qt Serial Port
   - ☑ Qt WebSockets
   - ☑ Qt Speech
   - ☑ Qt Image Formats
   - ☑ Qt Shader Tools
   - ☑ Qt State Machine (SCXML)
   - ☑ Qt Graphs
   - ☑ Qt HTTP Server
   *(If unsure, tick all add-on libraries under 6.10.3 — over-installing only costs disk.)*
7. **CMake + Ninja** — in current installers these are NOT under the Qt version. Expand the
   **top-level "Tools"** node (older installers called this "Developer and Designer Tools")
   and tick:
   - ☑ **CMake**
   - ☑ **Ninja**  (installs to `C:\Qt\Tools\Ninja\`)
   *Optional:* if you ticked "C++ CMake tools for Windows" in Step 1, you already have both
   from MSVC and can skip these. They were warnings, not blockers.
8. **Next → Install.** ~15–25 GB.

---

## STEP 3 — Re-verify

```powershell
cd "C:\Users\Anas-NX\OneDrive\NEXAM\10_Systems_Engineering\Systems_Engineering\STRATUM-Desktop"
powershell -ExecutionPolicy Bypass -File .\check-build-env.ps1
```

Expect **all PASS, no BLOCKERS**. The expected Qt path is
`C:\Qt\6.10.3\msvc2022_64\bin\qt-cmake.bat`.

---

## STEP 4 — Build

Follow **BUILD-Windows.md** — open *Developer PowerShell for VS 2022* and run the
`qt-cmake` + `cmake --build` sequence (Debug first).

---

## Tradespace notes

- **Build Tools vs full Visual Studio.** Build Tools = lighter, headless, sufficient to
  compile and link. The IDE buys you a debugger and editor you may not need if you build
  from the command line. Choose by whether you'll debug C++ in-IDE.
- **The MinGW trap, restated.** The Qt installer offers a MinGW kit on the same screen as
  MSVC. Picking it is the single most common way to waste an afternoon: GStreamer and the
  CI-built binaries are MSVC-ABI only. One wrong checkbox is an emergent, link-time failure.
- **Qt version discipline.** Only 6.10.x satisfies this tree's enforced minimum. A 6.9 kit
  installs fine and then fails at CMake configure. Match the version exactly.
