import QGroundControl
import QGroundControl.Controls

// STRATUM: Engage command (placeholder). Intended to invoke a PX4 flight mode; the
// command wiring is deliberately deferred. Presented as an accent command button in
// the left command strip.
ToolStripAction {
    text:       qsTr("Engage")
    iconSource: "/res/chevron-double-right.svg"
    enabled:    true
    visible:    true

    onTriggered: {
        // STRATUM: placeholder - PX4 flight-mode engagement to be wired in later.
    }
}
