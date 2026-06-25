# Prompt — Align STRATUM (QGroundControl) with the new PX4 "Standoff" flight mode

Paste everything below into a Claude session opened on the STRATUM
(`qgroundcontrol`) repository. It is self-contained.

---

## Role

You are a senior QGroundControl/PX4 integration engineer. You will modify this
STRATUM fork so that the existing "Standoff Here" feature drives a **new
in-firmware PX4 flight mode** instead of a guided reposition. Inspect before you
edit. Make the smallest set of changes that satisfies the contract below, and do
not refactor unrelated code.

## Background — what changed on the PX4 side (already done, do not re-implement)

The PX4 firmware now has a first-class auto flight mode, **Standoff**:

- New nav state `NAVIGATION_STATE_STANDOFF` at slot **9**, exposed over MAVLink
  as PX4 custom mode **main = AUTO (4)**, **sub = 20**
  (`PX4_CUSTOM_SUB_MODE_STANDOFF`).
- The mode is fed by a **custom MAVLink command, id `31010`**
  (`MAV_CMD_USER_1`, used here as `MAV_CMD_DO_STANDOFF`), sent as a
  **`COMMAND_INT`** in a **global** frame. PX4 decodes it into an internal
  `standoff_setpoint` topic and owns all the geometry: it translates the target
  by `distance` along `direction`, flies there at the commanded height, and yaws
  to face the target.

### Wire contract PX4 now expects

`COMMAND_INT`, command `31010`, frame `MAV_FRAME_GLOBAL_RELATIVE_ALT` (6):

| Field  | Meaning |
|--------|---------|
| x      | **target** latitude × 1e7 (the clicked point, NOT the offset point) |
| y      | **target** longitude × 1e7 |
| z      | standoff **height above home** [m] (relative — PX4 adds home altitude) |
| param1 | standoff **distance** from target [m] |
| param2 | standoff **direction** — compass bearing from target to hold point [deg, 0=N, CW] |
| param3 | 0 |
| param4 | NaN (let PX4 choose final yaw; it faces the target) |

Mode selection: `MAV_CMD_DO_SET_MODE` with
`MAV_MODE_FLAG_CUSTOM_MODE_ENABLED`, `custom_main_mode = 4`,
`custom_sub_mode = 20`.

## What STRATUM does today (verify by reading these files)

- `src/FlyView/StandoffController.qml` — `beginStandoff(distance, height, angle)`
  computes the **offset** standoff point client-side
  (`_targetCoordinate.atDistanceAndAzimuth`), computes an approach heading, and
  calls `_activeVehicle.guidedModeStandoff(standoffPoint, amslAltitude, approachHeadingDeg)`.
  On arrival it calls `guidedModeChangeHeading(target)`.
- `src/Vehicle/Vehicle.cc` — `Vehicle::guidedModeStandoff(...)` forwards to the
  firmware plugin.
- `src/FirmwarePlugin/PX4/PX4FirmwarePlugin.cc` — `guidedModeStandoff(...)`
  sends **`MAV_CMD_DO_REPOSITION`** (COMMAND_INT, `MAV_FRAME_GLOBAL`) with the
  offset point, an **AMSL** altitude, and yaw, with the CHANGE_MODE flag. (Note:
  the comment line in this function begins with a stray backslash `\` instead of
  `//` — verify it actually compiles and fix if needed.)
- `src/FirmwarePlugin/PX4/px4_custom_mode.h` — **STALE**: `PX4_CUSTOM_SUB_MODE_AUTO`
  stops at `PX4_CUSTOM_SUB_MODE_AUTO_PRECLAND = 9`. It has no VTOL_TAKEOFF,
  EXTERNAL1..8, GUIDED_COURSE, or STANDOFF, so it cannot express sub-mode 20.
- `src/FirmwarePlugin/PX4/PX4FirmwarePlugin.cc` (constructor, ~lines 44–88) —
  `_setModeEnumToModeStringMapping({...})` and the `availableFlightModes` list
  build the flight-mode menu from `PX4CustomMode::Mode` enum values.

**Mismatch:** STRATUM implements standoff as a reposition with client-side
geometry; it does not switch to a flight mode and cannot name sub-mode 20. The
firmware now wants the target + geometry via command `31010` and a switch to the
Standoff flight mode.

## Required changes

### 1. Update `src/FirmwarePlugin/PX4/px4_custom_mode.h`

Bring `PX4_CUSTOM_SUB_MODE_AUTO` in line with current PX4 so that **STANDOFF == 20**.
The firmware enum is, in order:

```
READY=1, TAKEOFF=2, LOITER=3, MISSION=4, RTL=5, LAND=6,
RESERVED_DO_NOT_USE=7 (this fork calls it RTGS — same value, keep it),
FOLLOW_TARGET=8, PRECLAND=9, VTOL_TAKEOFF=10,
EXTERNAL1=11 … EXTERNAL8=18, GUIDED_COURSE=19, STANDOFF=20
```

Add the missing entries (10–20) so `PX4_CUSTOM_SUB_MODE_AUTO_STANDOFF` resolves
to 20. Do **not** renumber existing entries. Then add to `struct PX4CustomMode`:

```cpp
AUTO_STANDOFF = PX4_CUSTOM_MAIN_MODE_AUTO <<16 | (PX4_CUSTOM_SUB_MODE_AUTO_STANDOFF << 24),
```

### 2. Register the flight mode — `PX4FirmwarePlugin.cc` constructor

- Add `const QString standoffFlightModeName = tr("Standoff");`
- Add to `_setModeEnumToModeStringMapping`:
  `{ PX4CustomMode::AUTO_STANDOFF, standoffFlightModeName },`
- Add to `availableFlightModes`:
  `{ standoffFlightModeName, PX4CustomMode::AUTO_STANDOFF, true, true },`
  (settable, advanced). This makes "Standoff" appear in the flight-mode menu and
  makes PX4's reported mode display as "Standoff".

### 3. Send the new contract — change the data path

In `PX4FirmwarePlugin::guidedModeStandoff(...)` (or a new method), replace the
`MAV_CMD_DO_REPOSITION` send with a `COMMAND_INT` carrying command **31010**:

- frame `MAV_FRAME_GLOBAL_RELATIVE_ALT`
- param1 = distance [m], param2 = bearing [deg], param3 = 0, param4 = NaN
- x/y = **target** lat/lon (pass `targetCoord.latitude()/longitude()` — QGC scales)
- z = **relative height** [m] (NOT AMSL)

Because `31010` may not be a named `MAV_CMD` in this dialect, use
`MAV_CMD_USER_1` if available, else `static_cast<MAV_CMD>(31010)`.

The method signature must now carry the **target** coordinate, **distance**,
**bearing**, and **relative height** — not a pre-computed offset point and AMSL.
Update `Vehicle::guidedModeStandoff` and the `FirmwarePlugin` virtual
declaration to match.

### 4. Rework `StandoffController.qml` `beginStandoff()`

- Send the geometry via the updated `guidedModeStandoff` using
  `_targetCoordinate` (the clicked point), `_standoffDistance`, `_standoffAngle`,
  and the **relative** `_standoffHeight` (do not pre-add home altitude).
- Then switch the vehicle into the new mode, e.g.
  `_activeVehicle.flightMode = "Standoff"` (or
  `_activeVehicle.setFlightMode("Standoff")` per this fork's API). Send the
  geometry **before** the mode switch.
- Keep the on-map surveillance circle (client-side offset point is fine for
  display only).
- **Remove** the arrival-detection `guidedModeChangeHeading(target)` logic — PX4
  now faces the target itself, and an extra DO_REPOSITION/heading command would
  fight the mode. Keep the optional "promote to Orbit" path if desired.

### 5. (Optional) Supported-commands list

If this fork gates outbound commands, ensure `31010` is permitted. Sending via
`sendMavCommandInt` generally does not require it, but verify.

## Verification

1. Build STRATUM. Confirm `px4_custom_mode.h` yields
   `PX4_CUSTOM_SUB_MODE_AUTO_STANDOFF == 20` (assert or log it).
2. Run against PX4 SITL (`make px4_sitl gz_x500`) with the firmware that has the
   Standoff mode.
3. Confirm "Standoff" appears in the flight-mode menu and that selecting it makes
   the vehicle report mode "Standoff" (`vehicle_status.nav_state == 9`).
4. Click a target → "Standoff Here" → enter distance/height/angle → confirm the
   vehicle flies to the point `distance` away on `angle`, at `height` above home,
   and yaws to face the target. Inspect PX4 `listener standoff_setpoint` and
   `listener position_setpoint_triplet`.
5. Confirm the command is acknowledged `ACCEPTED` (PX4 acks `31010` when lat/lon
   are finite). Watch for `MAV_RESULT` in the MAVLink console.

## Guardrails

- Send the **target**, not the offset point; send **relative** height, not AMSL;
  use a **global** frame (a local frame corrupts lat/lon scaling).
- The sub-mode value **must** be 20. If you only append STANDOFF after PRECLAND
  without the intermediate entries it becomes 10 — wrong mode.
- Keep `px4_custom_mode.h` append-only and aligned with firmware ordering to
  prevent future drift.
- Do not modify mission/orbit code paths beyond what is required here.
