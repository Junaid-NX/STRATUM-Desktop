import QGroundControl
import QGroundControl.Controls

// STRATUM: Engage command. Commands the vehicle directly into the PX4 custom
// "Engagement" flight mode (AUTO main / sub_mode 21), which already exists in
// firmware and waits for this trigger. The onTriggered handler is supplied where
// this action is added to the strip model (FlyViewToolStripActionList) so it can
// reach the active vehicle. Enabled only when a vehicle is connected.
ToolStripAction {
    id: root

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    text:       qsTr("Engage")
    iconSource: "/res/chevron-double-right.svg"
    enabled:    !!_activeVehicle
    visible:    true
}
