import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

// STRATUM Dropper tool-strip action. Mirrors the payload-drop and payload-load
// behaviour of the UAV-VAS web UI exactly:
//   * DROP  — select a single payload (PLD 1-4) or BURST, then commit with DROP.
//   * LOAD  — open all gates, then close/load payloads sequentially (1 -> 4).
//   * CAMERA — gimbal / feed controls (see FlyViewCameraControls).
// Servo commands use MAV_CMD 31012 on the bridge companion component (191), the
// same contract the web UI drives through /api/command (servo-drop / servo-burst
// / servo-load).
ToolStripAction {
    id: action

    text: qsTr("Dropper")
    iconSource: "qrc:/res/DropArrow.svg"
    enabled: !!QGroundControl.multiVehicleManager.activeVehicle
    visible: true

    // STRATUM: driven down from FlyView -> WidgetLayer -> ToolStrip so the panel
    // knows whether the camera is the maximized window (controls move to the video
    // overlay) or the map is maximized (controls stay inside this dropper panel).
    property bool cameraMaximized: false

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property string _dropperSection: "drop"
    property var _dropperState: ({ selectedMode: null, selectedPayloadIdx: null, dropped: [false, false, false, false], loaded: [false, false, false, false] })
    property string _dropperStatusText: qsTr("Dropper ready")

    function _showDropperSection(section) {
        _dropperSection = section
    }

    function _setStatus(text) {
        _dropperStatusText = text
    }

    // ---- DROP: select-then-commit (matches web UI selectDrop / onDropClick) ----
    function _selectDrop(mode, index) {
        if (mode === "burst") {
            _dropperState.selectedMode = "burst"
            _dropperState.selectedPayloadIdx = null
        } else if (_dropperState.selectedMode === "single" && _dropperState.selectedPayloadIdx === index) {
            // Toggle off if the same payload is tapped again.
            _dropperState.selectedMode = null
            _dropperState.selectedPayloadIdx = null
        } else {
            _dropperState.selectedMode = "single"
            _dropperState.selectedPayloadIdx = index
        }
        // Reassign so the change is observable by QML bindings.
        _dropperState = Object.assign({}, _dropperState)
    }

    function _executeDrop() {
        if (!_activeVehicle || !_dropperState.selectedMode) {
            return
        }
        if (_dropperState.selectedMode === "burst") {
            _activeVehicle.sendCommand(191, 31012, true, 10, 0, 0, 0, 0, 0, 0, 0)
            _dropperState.dropped = [true, true, true, true]
            _dropperStatusText = qsTr("⚡ BURST — all payloads deployed")
        } else {
            const index = _dropperState.selectedPayloadIdx
            const bits = [0, 0, 0, 0]
            bits[index] = 1
            _activeVehicle.sendCommand(191, 31012, true, 5, bits[0], bits[1], bits[2], bits[3], 0, 0, 0)
            _dropperState.dropped[index] = true
            _dropperStatusText = qsTr("⚡ PLD %1 deployed").arg(index + 1)
        }
        _dropperState.selectedMode = null
        _dropperState.selectedPayloadIdx = null
        _dropperState = Object.assign({}, _dropperState)
    }

    // ---- LOAD: open-all-gates + sequential load (matches doUnloadAll / doLoadPayload) ----
    function _dropperCanLoad(index) {
        if (index === 0) {
            return true
        }
        return _dropperState.loaded[index - 1]
    }

    function _dropperLoadPayload(index) {
        if (!_activeVehicle) {
            return
        }
        // Close servos 1..index (hold payload), keep index+1..4 open to receive more.
        const bits = [0, 0, 0, 0]
        for (let i = index + 1; i < 4; i++) {
            bits[i] = 1
        }
        _activeVehicle.sendCommand(191, 31012, true, 5, bits[0], bits[1], bits[2], bits[3], 0, 0, 0)
        for (let i = 0; i <= index; i++) {
            _dropperState.loaded[i] = true
            _dropperState.dropped[i] = false
        }
        _dropperState = Object.assign({}, _dropperState)
        _dropperStatusText = qsTr("✓ PLD %1 loaded").arg(index + 1)
    }

    function _dropperUnloadAll() {
        if (!_activeVehicle) {
            return
        }
        _activeVehicle.sendCommand(191, 31012, true, 10, 0, 0, 0, 0, 0, 0, 0)
        _dropperState.loaded = [false, false, false, false]
        _dropperState.dropped = [false, false, false, false]
        _dropperState.selectedMode = null
        _dropperState.selectedPayloadIdx = null
        _dropperState = Object.assign({}, _dropperState)
        _dropperStatusText = qsTr("✓ All gates opened — load payloads sequentially")
    }

    dropPanelComponent: Component {
        FlyViewDropperPanel {
            dropperAction: action
        }
    }
}
