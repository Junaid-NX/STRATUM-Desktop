import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// STRATUM Dagger camera / gimbal control cluster (SIYI A2 mini).
// The A2 mini is a single-axis (tilt only) FPV gimbal so this exposes only what the
// hardware supports: pitch up/down (hold-to-repeat), center, capture, record toggle,
// and a motion-mode cycle. All commands are sent as SIYI SDK v3 UDP packets by
// VideoManager::sendSiyiCameraAction(), whose destination host/port are configured
// in Application Settings > Video (daggerCameraSdkHost / daggerCameraSdkPort).
Item {
    id: root

    property bool overlayMode: false
    property bool compact: false

    signal statusMessage(string text)

    property bool _recActive: false

    readonly property color _accent:    "#3DFFA6"
    readonly property color _accentDim: "#1FB97D"
    readonly property real  _btnHeight: ScreenTools.defaultFontPixelHeight * (compact ? 1.9 : 2.3)
    readonly property real  _spacing:   ScreenTools.defaultFontPixelWidth * 0.4
    readonly property real  _pad:       overlayMode ? ScreenTools.defaultFontPixelWidth * 0.75 : 0

    implicitWidth:  contentColumn.implicitWidth + (_pad * 2)
    implicitHeight: contentColumn.implicitHeight + (_pad * 2)

    function _send(cameraAction) {
        const sent = QGroundControl.videoManager.sendSiyiCameraAction(cameraAction)
        if (!sent) {
            root.statusMessage(qsTr("Camera command failed"))
        }
        return sent
    }

    function _toggleRec() {
        _recActive = !_recActive
        if (_send("rec-toggle")) {
            root.statusMessage(_recActive ? qsTr("● Recording started") : qsTr("■ Recording stopped"))
        } else {
            _recActive = !_recActive // roll back on failure
        }
    }

    // Hold-to-move pitch button: fires the rate command while held (200 ms repeat) and
    // sends "stop" on release, mirroring the Dropper PtzButton pattern.
    component PtzButton : QGCButton {
        id: ptzButton
        property string ptzAction
        implicitHeight: root._btnHeight
        Layout.fillWidth: true
        onPressedChanged: {
            if (pressed) {
                root._send(ptzAction)
                ptzHoldTimer.restart()
            } else {
                ptzHoldTimer.stop()
                root._send("stop")
            }
        }
        Timer {
            id: ptzHoldTimer
            interval: 200
            repeat: true
            onTriggered: root._send(ptzButton.ptzAction)
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.overlayMode
        color: Qt.rgba(0, 0, 0, 0.72)
        radius: ScreenTools.defaultBorderRadius
        border.color: root._accent
        border.width: 1
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: root._pad
        spacing: root._spacing

        // Label
        QGCLabel {
            text: qsTr("A2 MINI")
            color: root._accentDim
            font.pointSize: ScreenTools.smallFontPointSize
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        // ---- Pitch (single-axis) --------------------------------------
        PtzButton { text: qsTr("▲  Pitch Up");   ptzAction: "pitch-up" }
        QGCButton {
            text: qsTr("⊙  Center")
            implicitHeight: root._btnHeight
            Layout.fillWidth: true
            onClicked: { if (root._send("center")) root.statusMessage(qsTr("Gimbal centred")) }
        }
        PtzButton { text: qsTr("▼  Pitch Down"); ptzAction: "pitch-down" }

        Item { Layout.preferredHeight: root._spacing }

        // ---- Media: Capture / Record --------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: root._spacing

            QGCButton {
                text: qsTr("📷 Capture")
                implicitHeight: root._btnHeight
                Layout.fillWidth: true
                onClicked: { if (root._send("capture")) root.statusMessage(qsTr("📷 Photo captured")) }
            }
            QGCButton {
                text: root._recActive ? qsTr("■ Stop") : qsTr("● Rec")
                implicitHeight: root._btnHeight
                Layout.fillWidth: true
                primary: root._recActive
                onClicked: root._toggleRec()
            }
        }

        // ---- Motion mode cycle (Lock / Follow / FPV) ----------------
        QGCButton {
            text: qsTr("Mode")
            implicitHeight: root._btnHeight
            Layout.fillWidth: true
            onClicked: { if (root._send("mode-cycle")) root.statusMessage(qsTr("Gimbal mode cycled")) }
        }
    }
}
