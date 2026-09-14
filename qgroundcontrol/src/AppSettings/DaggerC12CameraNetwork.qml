import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// STRATUM: Reprogram the Dagger C12 gimbal's IP.
//
// Workflow (matches the operator instruction: connect cameras one at a time and
// change each one's IP so they can coexist on the same network):
//   1. Plug in one C12. It comes up on whatever IP is stored in
//      videoSettings.daggerC12Host (factory default 192.168.144.108).
//   2. Type the new IP in the field and press Apply. STRATUM sends the Skydroid
//      "IPV" set command to the *current* IP, then updates daggerC12Host to the
//      new value. The camera reboots on the new IP and every subsequent command
//      (zoom, pan, record, tracker, etc.) goes to it automatically.
//   3. Unplug that camera, plug in the next one, repeat.
SettingsGroupLayout {
    id: root
    Layout.fillWidth:       true
    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 40
    heading:                qsTr("Dagger Camera Control (C12)")

    readonly property var _vs: QGroundControl.settingsManager.videoSettings

    QGCLabel {
        Layout.fillWidth:   true
        Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 60
        wrapMode:           Text.WordWrap
        text:               qsTr("The C12 gimbal ships with a fixed factory IP (192.168.144.108). If you plan to run more than one C12 on the same network, connect them one at a time and give each one a unique address below. The camera reboots with the new IP and STRATUM will start sending commands to it automatically.")
    }

    LabelledLabel {
        Layout.fillWidth:   true
        label:              qsTr("Current camera IP")
        labelText:          root._vs.daggerC12Host.rawValue
    }

    RowLayout {
        Layout.fillWidth:   true
        spacing:            ScreenTools.defaultFontPixelWidth

        QGCLabel {
            text:                       qsTr("New IP")
            Layout.preferredWidth:      ScreenTools.defaultFontPixelWidth * 12
        }

        QGCTextField {
            id:                 newIpField
            Layout.fillWidth:   true
            placeholderText:    qsTr("e.g. 192.168.144.109")
            // Dotted-quad IPv4; each octet 0-255. Empty text is invalid so Apply stays
            // disabled until the user types a complete address.
            validator: RegularExpressionValidator {
                regularExpression: /^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
            }
            onTextChanged: {
                if (statusLabel.text.length > 0) {
                    statusLabel.text = ""
                }
            }
        }

        QGCButton {
            text:       qsTr("Apply to Camera")
            enabled:    newIpField.acceptableInput && newIpField.text !== root._vs.daggerC12Host.rawValue
            onClicked: {
                const target = newIpField.text
                const currentBefore = root._vs.daggerC12Host.rawValue
                if (QGroundControl.videoManager.setC12CameraIp(target)) {
                    statusLabel.text  = qsTr("Sent to %1. Camera is rebooting on %2 — controls will resume in a few seconds.").arg(currentBefore).arg(target)
                    statusLabel.color = qgcPal.colorGreen
                    newIpField.text   = ""
                } else {
                    statusLabel.text  = qsTr("Could not reach camera at %1. Check the cable and that the camera is powered.").arg(currentBefore)
                    statusLabel.color = qgcPal.colorRed
                }
            }
        }
    }

    QGCLabel {
        id:                 statusLabel
        Layout.fillWidth:   true
        Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 60
        wrapMode:           Text.WordWrap
        visible:            text.length > 0
        text:               ""
    }
}
