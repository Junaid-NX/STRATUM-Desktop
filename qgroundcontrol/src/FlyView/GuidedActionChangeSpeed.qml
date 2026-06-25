import QGroundControl
import QGroundControl.FlyView

// STRATUM: Change max ground/air speed, surfaced as a first-class strip button
// (previously only reachable through the additional-actions panel).
GuidedToolStripAction {
    text:       qsTr("Max Speed")
    iconSource: "/res/ArrowRight.svg"
    visible:    _guidedController.showChangeSpeed
    enabled:    _guidedController.showChangeSpeed
    actionID:   _guidedController.actionChangeSpeed
}
