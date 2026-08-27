import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

// Label control whichs pop up a flight mode change menu when clicked
QGCLabel {
    id:     _root
    // STRATUM: current-mode label mirrors the picker relabelling (Position -> Manual).
    text:   currentVehicle
            ? (currentVehicle.flightMode === qsTr("Position") ? qsTr("Manual") : currentVehicle.flightMode)
            : qsTr("N/A", "No data to display")

    property var    currentVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property real   mouseAreaLeftMargin:    0

    Menu {
        id: flightModesMenu
    }

    Component {
        id: flightModeMenuItemComponent

        MenuItem {
            enabled: true
            // STRATUM: item's visible text can be remapped (see _stratumDisplayLabel).
            // Keep the real firmware mode name on the item so the flight-mode set
            // hits the correct PX4 mode regardless of the display label.
            property string stratumRealMode: text
            onTriggered: currentVehicle.flightMode = stratumRealMode
        }
    }

    property var flightModesMenuItems: []

    // STRATUM: operator UX spec whitelist -- mirrors FlightModeIndicator.qml. Empty to
    // restore upstream behaviour (all firmware modes shown).
    readonly property var _stratumAllowedFlightModes: [
        qsTr("Takeoff"), qsTr("Land"),
        qsTr("Safe Recovery"), qsTr("Return"),
        qsTr("Position"),
        qsTr("Standoff"), qsTr("Engagement"),
        qsTr("Hold"), qsTr("Abort")
    ]

    // STRATUM: PX4 "Position" (POSCTL) is what the operator picks as "Manual". The menu
    // item label is remapped here, but the flight-mode string sent to the vehicle stays
    // "Position" -- see the onTriggered handler on flightModeMenuItemComponent.
    function _stratumDisplayLabel(mode) {
        if (mode === qsTr("Position")) {
            return qsTr("Manual")
        }
        return mode
    }

    function updateFlightModesMenu() {
        if (currentVehicle && currentVehicle.flightModeSetAvailable) {
            var i;
            // Remove old menu items
            for (i = 0; i < flightModesMenuItems.length; i++) {
                flightModesMenu.removeItem(flightModesMenuItems[i])
            }
            flightModesMenuItems.length = 0
            var modes = currentVehicle.flightModes
            if (_stratumAllowedFlightModes.length > 0) {
                modes = modes.filter(function(m) {
                    return _stratumAllowedFlightModes.indexOf(m) !== -1
                })
            }
            // Add new items
            for (i = 0; i < modes.length; i++) {
                var menuItem = flightModeMenuItemComponent.createObject(null, {
                    "text": _stratumDisplayLabel(modes[i]),
                    "stratumRealMode": modes[i]
                })
                flightModesMenuItems.push(menuItem)
                flightModesMenu.insertItem(i, menuItem)
            }
        }
    }

    Component.onCompleted: _root.updateFlightModesMenu()

    Connections {
        target:                 QGroundControl.multiVehicleManager
        function onActiveVehicleChanged(activeVehicle) { _root.updateFlightModesMenu() }
    }

    Connections {
        target: currentVehicle
        function onFlightModesChanged() { _root.updateFlightModesMenu() }
    }

    MouseArea {
        id:                 mouseArea
        visible:            currentVehicle && currentVehicle.flightModeSetAvailable
        anchors.leftMargin: mouseAreaLeftMargin
        anchors.fill:       parent
        onClicked:          flightModesMenu.popup((_root.width - flightModesMenu.width) / 2, _root.height)
    }
}
