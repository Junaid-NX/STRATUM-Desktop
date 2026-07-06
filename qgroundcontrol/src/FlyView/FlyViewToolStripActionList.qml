import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Viewer3D

ToolStripActionList {
    id: _root

    property var engagementController    // STRATUM: engagement/abort safety-loop controller
    property bool cameraMaximized: false // STRATUM: true when the video is the maximized window

    signal displayPreFlightChecklist
    signal defineAOP      // retained: emitters relocated to the ribbon (FlyViewToolBar)
    signal setStandoff    // retained: emitters relocated to the ribbon (FlyViewToolBar)

    // STRATUM: the command strip now carries ONLY the six flight-mode commands pulled
    // from the mode menu -- Standoff / Land / Hold / Abort / Engagement / Vision
    // Engagement -- each a hold-to-confirm button that switches FLIGHT MODE directly
    // (the mode menu's working path). Define AOP and Set Standoff were relocated to the
    // centre of the top ribbon; Takeoff and Safe Recovery were removed from the strip.
    model: [
        GuidedActionStandoffMode { },       // Standoff flight mode (hold-to-confirm)
        GuidedActionLand { },               // Land flight mode
        GuidedActionHold { },               // Hold flight mode
        GuidedActionAbort { },              // PX4 custom "Abort" flight mode (sub=22)
        FlyViewDropperAction { cameraMaximized: _root.cameraMaximized },
        // STRATUM: PX4 custom "Engagement" flight mode (sub=21). Routed through the
        // engagement controller so the abort destination is armed (PARAM_SET) before commit.
        EngageAction {
            onTriggered: {
                if (_root.engagementController) {
                    _root.engagementController.engage()
                } else if (QGroundControl.multiVehicleManager.activeVehicle) {
                    QGroundControl.multiVehicleManager.activeVehicle.flightMode = qsTr("Engagement")
                }
            }
        },
        // STRATUM: PX4 custom "Vision Engagement" flight mode (sub=23) -- camera-guided,
        // no map target. Reuses the SAME engagement controller (arm-on-engage).
        VisionEngageAction {
            onTriggered: {
                if (_root.engagementController) {
                    _root.engagementController.visionEngage()
                } else if (QGroundControl.multiVehicleManager.activeVehicle) {
                    QGroundControl.multiVehicleManager.activeVehicle.flightMode = qsTr("Vision Engagement")
                }
            }
        }
    ]
}
