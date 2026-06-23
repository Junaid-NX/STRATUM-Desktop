# STRATUM-Desktop — Fly View Override-Surface Map

*Scope: the vehicle (Fly) view only. Plan view excluded. Grounded in the QGC source under `qgroundcontrol/src/FlyView` and `qgroundcontrol/src/Toolbar`.*

This document is the implementation contract between the visual design (Figma) and the QML build. Every element a designer might touch is listed with **who owns it**, **where it lives on screen**, **how it behaves under the layout contract**, and **how far you are allowed to change it without incurring systemic risk**.

---

## 1. The layout contract you cannot draw in Figma

The Fly view is not a free canvas. It is a stack of full-screen layers composited by z-order, and the visible widgets are positioned by **`QGCToolInsets`** — a constraint-propagation system. Each widget *declares how much screen edge it consumes* (`leftEdgeTopInset`, `bottomEdgeRightInset`, etc.); those declarations bubble up to the map, which recenters the vehicle into whatever free space remains. Dimensions are expressed in **`ScreenTools.defaultFontPixelWidth`** units, not pixels, so the layout reflows across screens and DPI.

**Consequence for design:** a Figma frame encodes absolute pixels; this view encodes relational constraints. Use Figma for the *visual system* (color, iconography, button morphology, typography, hierarchy). Specify *layout* as zones tied to the inset edges below, never as pixel coordinates.

### Layer stack (bottom → top), from `FlyView.qml`

| z-order | Layer | File | Role |
|---|---|---|---|
| 0 | Map / Video | `FlyViewMap.qml`, `FlyViewVideo.qml` | The world. Engine, not chrome. |
| `zOrderWidgets` | PiP view | (`PipView` in `FlyView.qml`) | Map/video picture-in-picture swap. |
| full+2 | **Widget layer** | `FlyViewWidgetLayer.qml` | All stock buttons/instruments. |
| full+2 | **Custom layer** | `FlyViewCustomLayer.qml` | **Your overlay. Declared last → draws on top.** |
| `zOrderTopMost` | Guided value slider | `GuidedValueSlider.qml` | Altitude/value slider, hidden until used. |
| top | **Toolbar** | `Toolbar/FlyViewToolBar.qml` | The top status/indicator bar. |

---

## 2. Element inventory by zone

### 2.1 Top bar — `Toolbar/FlyViewToolBar.qml` → `FlyViewToolBarIndicators.qml`

A separate layer from the widget/custom overlays. Holds the status indicators.

| Element | File | Notes |
|---|---|---|
| View selector dropdown | `SelectViewDropdown.qml` | Switches Fly/Plan/Analyze. |
| Main status / vehicle messages | `MainStatusIndicator.qml`, `VehicleMessageList.qml` | Primary health + message feed. |
| Flight mode | `FlightModeIndicator.qml`, `FlightModeMenuIndicator.qml` | |
| Armed state | `ArmedIndicator.qml` | |
| Battery | `BatteryIndicator.qml` | |
| GPS / RTK / resilience | `GPSIndicator.qml`, `RTKGPSIndicator.qml`, `GPSResilienceIndicator.qml` | |
| RC / telemetry RSSI | `RCRSSIIndicator.qml`, `TelemetryRSSIIndicator.qml`, `SignalStrength.qml` | |
| Gimbal, ESC, Joystick, RemoteID, GCS, Mode | `GimbalIndicator.qml`, `EscIndicator.qml`, `JoystickIndicator.qml`, `RemoteIDIndicator.qml`, `GCSControlIndicator.qml`, `ModeIndicator.qml` | |
| Multi-vehicle selector | `MultiVehicleSelector.qml` | |

Override hook in the custom build: the example ships `CustomToolBarButton.qml`.

### 2.2 Widget layer — `FlyViewWidgetLayer.qml`

| Zone | Element | File | Inset it reports |
|---|---|---|---|
| Top-left | Tool strip (vertical action buttons) | `FlyViewToolStrip.qml` → model in `FlyViewToolStripActionList.qml` | `leftEdgeTopInset`, `topEdgeLeftInset` |
| Top-left (right of strip) | Map scale | `MapScale` (QmlControls) | `topEdgeCenterInset` |
| Top-right (multi-vehicle) | Multi-vehicle panel: vehicle list, Arm/Disarm/Start/Pause, photo/video swipe | `FlyViewTopRightPanel.qml`, `MultiVehicleList.qml` | `rightEdgeTopInset`, `topEdgeRightInset` |
| Top-right (single vehicle) | Terrain progress + photo/video control | `FlyViewTopRightColumnLayout.qml`, `TerrainProgress.qml` | `rightEdgeTopInset` |
| Bottom-right | Telemetry value bar + instrument panel | `FlyViewBottomRightRowLayout.qml`, `TelemetryValuesBar.qml`, `FlyViewInstrumentPanel.qml` | `bottomEdgeRightInset`, `bottomEdgeCenterInset` |
| Center | Vehicle warnings | `VehicleWarnings.qml` | (top-most, no inset) |
| Bottom-left | Virtual joystick (optional) | `VirtualJoystick.qml` (via Loader) | `leftEdgeBottomInset`, `bottomEdgeLeftInset` |
| Modal | Pre-flight checklist popup | `FlyViewPreFlightChecklistPopup.qml` + `*Checklist.qml` | — |

**Tool strip button set** (the most likely first customization), from `FlyViewToolStripActionList.qml`:
`Viewer3DShowAction`, `PreFlightCheckListShowAction`, `GuidedActionTakeoff`, `GuidedActionLand`, `GuidedActionRTL`, `GuidedActionPause`, `FlyViewAdditionalActionsButton`, `FlyViewGripperButton`.

### 2.3 Custom layer — `FlyViewCustomLayer.qml` (your canvas)

Stock version is a pass-through that just forwards parent insets. The `custom-example` override fills it with a compass bar, heading indicator, and attitude widget built from `Custom.Widgets` components (`CustomAttitudeWidget`, `CustomIconButton`, `CustomQuickButton`, `CustomOnOffSwitch`, `CustomSignalStrength`). **This is where you add freely.**

---

## 3. Override classification — Replace / Augment / Leave-alone

The classification answers one question: *how do I change this, and what does it cost?*

| Element / Concern | Verdict | Mechanism | Risk |
|---|---|---|---|
| New custom widgets, instruments, branded overlays | **Augment** | Add to your `FlyViewCustomLayer.qml` override + `Custom.Widgets` module | Low. Sanctioned path. |
| Tool strip button set | **Replace** | Override `FlyViewToolStripActionList.qml` | Low–Med. Pure model swap. |
| Top-bar indicators & buttons | **Replace** | Override individual indicator QML / `FlyViewToolBarIndicators.qml`; style via `CustomToolBarButton` | Med. Many small files. |
| Instrument panel / telemetry bar contents | **Replace/Augment** | Override `FlyViewInstrumentPanel.qml`, configure `FactValueGrid` | Med. Driven by Fact system + settings. |
| Whole-view re-layout (move zones around) | **Replace** | Override `FlyViewWidgetLayer.qml` in full | **High.** You inherit the entire inset contract. Touch only when re-skin is insufficient. |
| Color / typography / theme tokens | **Augment** | `QGCPalette`, `ScreenTools`, corePlugin options | Low. Theme-level, global reach. |
| `QGCToolInsets` propagation model | **Leave alone** | — | **Critical.** Break it and widgets collide / map mis-centers. |
| Guided-action logic, `PlanMasterController`, mission/guided controllers | **Leave alone** | — | **Critical.** Behavior + safety, not chrome. Re-skin the buttons, never the controller. |
| Map / video engine | **Leave alone** | — | High. Not a UI concern. |

**Rule of thumb:** the deeper a change sits in this table, the more it is a *business-risk decision* and not a styling decision. Re-skinning the tool strip is reversible in an afternoon. Forking `FlyViewWidgetLayer` commits you to maintaining QGC's layout math against every upstream release.

---

## 4. The decision that gates everything: custom-build wiring

There is currently **no STRATUM custom directory** in the repo — only the stock `custom-example/`. The build supports it (`QGC_CUSTOM_DIR` → `CustomOptions` / `CustomOverrides` / `add_subdirectory`), but it is not yet pointed at a STRATUM tree.

Until that exists, every "override" above has nowhere to live except by editing stock files in place — which destroys your upstream-merge story. **Stand up `custom/` (copied from `custom-example/`) before any design work is implemented.** That single architectural decision determines whether STRATUM rides QGC's release train or forks off it permanently.

---

## 5. Recommended path

1. **Wire the custom build** — create `custom/`, set `QGC_CUSTOM_DIR`, confirm a clean build with the example overlay visible.
2. **Design the visual system in Figma** — buttons, instruments, color/type tokens, iconography. Map each Figma component 1:1 to a future `Custom.Widgets` file.
3. **Prototype layout in QML, not Figma** — a throwaway `FlyViewCustomLayer.qml` is the only place the inset contract is real.
4. **Classify each desired change against §3** before building it — keep changes as high in that table as the requirement allows.
