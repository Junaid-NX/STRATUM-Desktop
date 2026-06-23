# Fly View — Static Web Reproduction

A non-functional, browser-only reproduction of QGroundControl's **Fly View** (vehicle view).
Pure HTML/CSS with inlined SVG. No build step, no dependencies, no live data.

## Run

```bash
cd flyview-web
node server.js
# open http://localhost:3000
```

Or just open `index.html` directly in a browser — the server is only for convenience.

## What it reproduces

Layout and dark-theme styling mirror the QGC source under `qgroundcontrol/src/FlyView`
and `src/Toolbar`. Colors are taken verbatim from `QGCPalette.cc` (dark theme), and the
tool-strip icons (takeoff, land, RTL, pause) are the actual QGC SVG paths.

- **Top toolbar** — view dropdown, flight-mode, armed state, GPS, RC/telemetry RSSI, battery, messages
- **Left tool strip** — 3D, checklist, takeoff, land, RTL, pause, more, gripper
- **Map underlay** — faux satellite, mission trajectory (orange), home, numbered waypoints, vehicle heading arrow
- **Map scale** (top-left)
- **Vehicle warnings** pill (center)
- **Bottom-right cluster** — telemetry value bar + compass + attitude (artificial horizon)

## What it is NOT

No telemetry, no MAVLink, no interactivity, no map panning. Static state is hardcoded
(multirotor, armed, "Hold" mode). This is a visual scaffold for design iteration — the
intended next step is to replace these static blocks with your STRATUM design language
before porting back to QML (`FlyViewCustomLayer.qml`). See `../FlyView_Override_Surface_Map.md`.

## Mapping back to QGC source

| Mockup block | QGC source |
|---|---|
| `#toolbar` | `src/Toolbar/FlyViewToolBar.qml` + indicators |
| `#toolStrip` | `FlyViewToolStrip.qml` / `FlyViewToolStripActionList.qml` |
| `#telemBar` | `TelemetryValuesBar.qml` |
| `#instruments` | `FlyViewInstrumentPanel.qml` / custom layer |
| `#mapScale` | `MapScale` (QmlControls) |
| `#warnings` | `VehicleWarnings.qml` |
| `#map` / `#mapVectors` | `FlyViewMap.qml` |
