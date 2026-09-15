import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// STRATUM: Dagger C12 camera control + reprogram UI.
//
// Two independent operations:
//   1. "Camera control IP" — where STRATUM sends every C12 command (zoom, pan,
//      tilt, track, palette, record, ...). Editing this field updates the fact
//      immediately so control follows the camera to its actual address without
//      requiring a reprogram. "Read from camera" queries the camera for its
//      real IP via the Skydroid rIPV command.
//   2. "Reprogram camera IP" — sends the Skydroid wIPV set command to the
//      currently-stored control IP and, on success, updates the control IP to
//      the new value so the next command lands on the reprogrammed camera.
SettingsGroupLayout {
    id: root
    Layout.fillWidth:       true
    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 42
    heading:                qsTr("Dagger Camera Control (C12)")

    readonly property var _vs:         QGroundControl.settingsManager.videoSettings
    readonly property string _ipRegex: "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"

    // -------- Section 1: control IP -----------------------------------------

    QGCLabel {
        Layout.fillWidth:       true
        Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 60
        wrapMode:               Text.WordWrap
        text:                   qsTr("Camera control IP — STRATUM sends every C12 command (zoom, pan, tilt, track, palette, record) to this address. Change it here whenever the camera's IP has changed.")
    }

    RowLayout {
        Layout.fillWidth:   true
        spacing:            ScreenTools.defaultFontPixelWidth

        QGCLabel {
            text:                   qsTr("Control IP")
            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 12
        }

        QGCTextField {
            id:                     controlIpField
            Layout.fillWidth:       true
            text:                   root._vs.daggerC12Host.rawValue
            placeholderText:        qsTr("e.g. 192.168.144.108")
            validator: RegularExpressionValidator {
                regularExpression:  new RegExp(root._ipRegex)
            }
            onEditingFinished: {
                if (acceptableInput && text !== root._vs.daggerC12Host.rawValue) {
                    root._vs.daggerC12Host.rawValue = text
                    controlStatus.text  = qsTr("Control IP set to %1.").arg(text)
                    controlStatus.color = qgcPal.colorGreen
                }
            }
            Connections {
                target: root._vs.daggerC12Host
                function onRawValueChanged() {
                    if (!controlIpField.activeFocus) {
                        controlIpField.text = root._vs.daggerC12Host.rawValue
                    }
                }
            }
        }

        QGCButton {
            text:       qsTr("Read from camera")
            onClicked: {
                controlStatus.text  = qsTr("Reading from %1 …").arg(root._vs.daggerC12Host.rawValue)
                controlStatus.color = qgcPal.text
                const reported = QGroundControl.videoManager.readC12CameraIp(1200)
                if (reported.length > 0) {
                    root._vs.daggerC12Host.rawValue = reported
                    controlIpField.text = reported
                    controlStatus.text  = qsTr("Camera reports %1. Control IP updated.").arg(reported)
                    controlStatus.color = qgcPal.colorGreen
                } else {
                    controlStatus.text  = qsTr("No reply from %1. Check the cable, power, and that this PC is on the same subnet.").arg(root._vs.daggerC12Host.rawValue)
                    controlStatus.color = qgcPal.colorRed
                }
            }
        }
    }

    QGCLabel {
        id:                     controlStatus
        Layout.fillWidth:       true
        Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 60
        wrapMode:               Text.WordWrap
        visible:                text.length > 0
        text:                   ""
    }

    // -------- Section 2: reprogram camera IP --------------------------------

    Rectangle {
        Layout.fillWidth:       true
        Layout.topMargin:       ScreenTools.defaultFontPixelHeight / 2
        Layout.bottomMargin:    ScreenTools.defaultFontPixelHeight / 2
        height:                 1
        color:                  qgcPal.windowShadeDark
    }

    QGCLabel {
        Layout.fillWidth:       true
        Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 60
        wrapMode:               Text.WordWrap
        text:                   qsTr("Reprogram camera IP — permanently change the IP the C12 boots with. Connect cameras one at a time so each one can be given a unique address. The camera reboots on the new IP and the control IP above is updated automatically.")
    }

    RowLayout {
        Layout.fillWidth:       true
        spacing:                ScreenTools.defaultFontPixelWidth

        QGCLabel {
            text:                   qsTr("New IP")
            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 12
        }

        QGCTextField {
            id:                     newIpField
            Layout.fillWidth:       true
            placeholderText:        qsTr("e.g. 192.168.144.109")
            validator: RegularExpressionValidator {
                regularExpression:  new RegExp(root._ipRegex)
            }
            onTextChanged: {
                if (reprogramStatus.text.length > 0) {
                    reprogramStatus.text = ""
                }
            }
        }

        QGCButton {
            text:       qsTr("Apply to Camera")
            enabled:    newIpField.acceptableInput && newIpField.text !== root._vs.daggerC12Host.rawValue
            onClicked: {
                const target        = newIpField.text
                const currentBefore = root._vs.daggerC12Host.rawValue
                if (QGroundControl.videoManager.setC12CameraIp(target)) {
                    reprogramStatus.text  = qsTr("Sent to %1. Camera is rebooting on %2 — control IP updated.").arg(currentBefore).arg(target)
                    reprogramStatus.color = qgcPal.colorGreen
                    newIpField.text       = ""
                } else {
                    reprogramStatus.text  = qsTr("Could not reach camera at %1. Check the cable and that the camera is powered.").arg(currentBefore)
                    reprogramStatus.color = qgcPal.colorRed
                }
            }
        }
    }

    QGCLabel {
        id:                     reprogramStatus
        Layout.fillWidth:       true
        Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 60
        wrapMode:               Text.WordWrap
        visible:                text.length > 0
        text:                   ""
    }
}
