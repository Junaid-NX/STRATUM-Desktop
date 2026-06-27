import QGroundControl
import QGroundControl.FlyView

// STRATUM: Safe Recovery. PX4's StandardModes advertises the RTL-class mode with the
// literal name "Safe Recovery" (MAV_STANDARD_MODE_SAFE_RECOVERY, see StandardModes.cc),
// so we command that exact name rather than vehicle.rtlFlightMode()/"Return", which is
// empty/unmatched under the dynamic AVAILABLE_MODES protocol. Same name the mode menu uses.
GuidedToolStripAction {
    property var _vehicle: QGroundControl.multiVehicleManager.activeVehicle

    text:       qsTr("Safe Recovery")
    iconSource: "/res/rtl.svg"
    visible:    true
    enabled:    !!_vehicle
    actionID:   _guidedController.actionSetFlightMode
    actionData: qsTr("Safe Recovery")
}
