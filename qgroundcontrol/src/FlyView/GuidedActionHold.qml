import QGroundControl
import QGroundControl.FlyView

// STRATUM: Hold (loiter at current position). Backed by the guided pause action.
GuidedToolStripAction {
    text:       qsTr("Hold")
    iconSource: "/res/pause-mission.svg"
    visible:    _guidedController.showPause
    enabled:    _guidedController.showPause
    actionID:   _guidedController.actionPause
}
