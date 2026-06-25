import QGroundControl
import QGroundControl.FlyView

// STRATUM: Change altitude, surfaced as a first-class strip button (previously only
// reachable through the additional-actions panel).
GuidedToolStripAction {
    text:       qsTr("Altitude")
    iconSource: "/res/chevron-up.svg"
    visible:    _guidedController.showChangeAlt
    enabled:    _guidedController.showChangeAlt
    actionID:   _guidedController.actionChangeAlt
}
