import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Viewer3D

ToolStripActionList {
    id: _root

    signal displayPreFlightChecklist
    signal defineAOP

    // STRATUM: focused command strip - AOP, the in-scope flight commands, and the two
    // surfaced guided adjustments (Altitude, Max Speed). The full flight-mode set remains
    // available via the toolbar dropdown for development. The legacy additional-actions
    // panel, gripper, 3D and checklist tool buttons were removed.
    model: [
        FlyViewAOPAction { onTriggered: defineAOP() },
        GuidedActionTakeoff { },
        GuidedActionRTL { },                // Return (RTB)
        GuidedActionHold { },
        GuidedActionLand { },
        GuidedActionChangeAltitude { },
        GuidedActionChangeSpeed { },        // Max Speed
        // STRATUM: dedicated trigger for the PX4 custom "Engagement" flight mode.
        // One tap commands the vehicle straight into the mode (no dialog); the
        // blinking ENGAGING! overlay (FlyView) confirms the active state.
        EngageAction {
            onTriggered: {
                if (QGroundControl.multiVehicleManager.activeVehicle) {
                    QGroundControl.multiVehicleManager.activeVehicle.flightMode = qsTr("Engagement")
                }
            }
        }
    ]
}
