import QGroundControl
import QGroundControl.Controls

// STRATUM: Tool-strip action that enters in-view Area-Of-Operations (AOP) edit
// mode. The AOP is the section's operating boundary and is committed to the
// vehicle as an inclusion geofence. This is not a guided action; it toggles an
// editing state on the Fly map via the FlyViewToolStripActionList.defineAOP signal.
ToolStripAction {
    id: root

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    text:       qsTr("Define AOP")
    iconSource: "/qmlimages/Plan.svg"
    // STRATUM: the AOP boundary can be defined with no vehicle connected — it is
    // an operator planning artifact first, a geofence upload second. The on-map
    // Apply/Cancel bar surfaces an "Apply changes" button only once a vehicle is
    // present, at which point the polygon can be committed as an inclusion fence.
    enabled:    true
    visible:    true
}
