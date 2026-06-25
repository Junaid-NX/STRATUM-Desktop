import QtQuick
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

// STRATUM: Standoff command controller.
//
// A standoff is a static hold relative to a target: the vehicle flies to a point
// offset from the target by the standoff distance, on the standoff bearing, at the
// standoff height, and faces the target. Geometrically this is one point on an orbit
// of radius = distance, centred on the target, at altitude = height. Once the vehicle
// arrives, the operator may promote the static hold into a live orbit using exactly
// those parameters.
Item {
    id: root

    property var    guidedController
    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property var    _unitsConversion:   QGroundControl.unitsConversion

    // Pending / active standoff state (all distances in METERS, angle in DEGREES)
    property var    _targetCoordinate:  QtPositioning.coordinate()
    property var    _standoffPoint:     QtPositioning.coordinate()
    property real   _standoffDistance:  0
    property real   _standoffHeight:    0
    property real   _standoffAngle:     0
    property bool   _awaitingArrival:   false
    // True from the moment a standoff is committed until it is cancelled. Drives the
    // on-map surveillance circle (centre = target, radius = standoff distance).
    property bool   _standoffActive:    false

    // Arrival tolerance scales gently with distance, floored for short standoffs.
    readonly property real _arrivalThresholdMeters: Math.max(5, _standoffDistance * 0.08)

    // Emitted whenever a new standoff point is computed; consumers (e.g. the map)
    // may use this to render a target / standoff indicator.
    signal standoffPointChanged(var targetCoordinate, var standoffCoordinate)

    QGCPopupDialogFactory {
        id:              standoffDialogFactory
        dialogComponent: standoffDialogComponent
    }
    Component {
        id: standoffDialogComponent
        StandoffDialog { standoffController: root }
    }

    QGCPopupDialogFactory {
        id:              orbitPromptFactory
        dialogComponent: orbitPromptComponent
    }
    Component {
        id: orbitPromptComponent
        StandoffOrbitDialog { standoffController: root }
    }

    // Open the parameter dialog for a freshly clicked target.
    function showStandoffDialog(targetCoordinate) {
        _awaitingArrival  = false
        _targetCoordinate = targetCoordinate
        standoffDialogFactory.open()
    }

    // Current AMSL altitude for the standoff/orbit (NaN if home altitude unknown).
    function _standoffAmslAltitude() {
        // NOTE: on a QML QGeoCoordinate, isValid is a PROPERTY (no parens); calling it
        // as a function throws and aborts the whole standoff command.
        if (!_activeVehicle || !_activeVehicle.homePosition.isValid || isNaN(_activeVehicle.homePosition.altitude)) {
            return NaN
        }
        return _activeVehicle.homePosition.altitude + _standoffHeight
    }

    // distanceUnits / heightUnits are in the user's configured units; angleDeg is a
    // compass bearing (0 = North, clockwise).
    function beginStandoff(distanceUnits, heightUnits, angleDeg) {
        if (!_activeVehicle) {
            return
        }
        _standoffDistance = _unitsConversion.appSettingsHorizontalDistanceUnitsToMeters(distanceUnits)
        _standoffHeight   = _unitsConversion.appSettingsVerticalDistanceUnitsToMeters(heightUnits)
        _standoffAngle    = angleDeg
        _standoffPoint    = _targetCoordinate.atDistanceAndAzimuth(_standoffDistance, _standoffAngle)
        standoffPointChanged(_targetCoordinate, _standoffPoint)

        // Heading the vehicle should hold at the standoff point: facing the target,
        // i.e. the bearing FROM the standoff point TO the target.
        var headingDeg = _standoffPoint.azimuthTo(_targetCoordinate)

        // Single combined reposition: position + altitude + heading in one command.
        // (Separate goto/altitude/heading collide on PX4 as duplicate DO_REPOSITIONs.)
        _activeVehicle.guidedModeStandoff(_standoffPoint, _standoffAmslAltitude(), headingDeg)

        _standoffActive  = true
        _awaitingArrival = true
    }

    // Promote the static standoff into an orbit using the same geometry.
    function confirmOrbit() {
        if (!_activeVehicle) {
            return
        }
        // Mirrors the stock orbit path (home altitude + relative height). Positive radius
        // => clockwise orbit around the target. The surveillance circle stays visible and
        // now depicts the active orbit area.
        var amslAltitude = _activeVehicle.homePosition.altitude + _standoffHeight
        _activeVehicle.guidedModeOrbit(_targetCoordinate, _standoffDistance, amslAltitude)
        _awaitingArrival = false
    }

    function cancelStandoff() {
        _awaitingArrival = false
        _standoffActive  = false
    }

    // Arrival detection: when the vehicle gets within tolerance of the standoff point,
    // offer to convert the hold into an orbit. Read the live coordinate directly rather
    // than relying on the notify signal argument.
    Connections {
        target:  _activeVehicle
        enabled: root._awaitingArrival && _activeVehicle

        function onCoordinateChanged() {
            if (!root._awaitingArrival || !_activeVehicle) {
                return
            }
            var horizontalDistance = _activeVehicle.coordinate.distanceTo(root._standoffPoint)
            if (horizontalDistance <= root._arrivalThresholdMeters) {
                root._awaitingArrival = false
                orbitPromptFactory.open()
            }
        }
    }
}
