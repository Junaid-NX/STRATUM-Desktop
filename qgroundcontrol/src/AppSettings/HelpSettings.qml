import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// STRATUM: temporary quick-start guide for field operators. Written in plain language;
// avoid technical/setup terms (no RTSP links, no comm-link setup). Final help content
// TBD -- keep this file as the single source of truth so it is easy to swap out.
Rectangle {
    objectName:     "settingsPage_Help"
    color:          qgcPal.window
    anchors.fill:   parent

    readonly property real _margins:     ScreenTools.defaultFontPixelHeight
    readonly property real _stepIndent:  ScreenTools.defaultFontPixelWidth * 3

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    QGCFlickable {
        anchors.margins:  _margins
        anchors.fill:     parent
        contentWidth:     content.width
        contentHeight:    content.height
        clip:             true

        ColumnLayout {
            id:      content
            width:   parent.width - (_margins * 2)
            spacing: _margins

            QGCLabel {
                text:            qsTr("Quick Start Guide")
                font.pointSize:  ScreenTools.largeFontPointSize * 1.4
                font.bold:       true
            }

            QGCLabel {
                Layout.fillWidth: true
                wrapMode:         Text.WordWrap
                text: qsTr("Welcome to STRATUM. This short guide covers the everyday tasks. " +
                           "For each task, follow the steps in order.")
            }

            // ----- How to fetch a target ---------------------------------
            QGCLabel {
                text:            qsTr("How to fetch a target")
                font.pointSize:  ScreenTools.largeFontPointSize
                font.bold:       true
            }
            QGCLabel {
                Layout.fillWidth: true
                Layout.leftMargin: _stepIndent
                wrapMode:         Text.WordWrap
                text: qsTr("1. On the Fly view tool strip on the right, press the green \"Connect Pod\" button. " +
                           "You only need to do this the first time you use the pod after turning it on.\n\n" +
                           "2. Wait until the status message says the pod is ready.\n\n" +
                           "3. Press the blue \"Fetch Target\" button. The app will listen to the pod for about 30 seconds. " +
                           "When a target is received, a pin will appear on the map showing where it is.\n\n" +
                           "4. If you want to clear the pin, press \"Fetch Target\" again to start a fresh capture.")
            }

            // ----- How to set a Standoff point ---------------------------
            QGCLabel {
                text:            qsTr("How to set a Standoff point")
                font.pointSize:  ScreenTools.largeFontPointSize
                font.bold:       true
            }
            QGCLabel {
                Layout.fillWidth: true
                Layout.leftMargin: _stepIndent
                wrapMode:         Text.WordWrap
                text: qsTr("The Standoff point is where the aircraft will hold and observe the target from a safe distance.\n\n" +
                           "1. Make sure a target pin is on the map (see \"How to fetch a target\" above), " +
                           "or tap-and-hold on the map at the location you want to observe.\n\n" +
                           "2. Open the Standoff panel from the Fly view tool strip and check the values:\n" +
                           "   • Distance — how far the aircraft stays from the target.\n" +
                           "   • Height — how high above the target the aircraft flies.\n" +
                           "   • Direction — which side of the target the aircraft holds on.\n\n" +
                           "3. Press \"Set Standoff\". The aircraft will fly to the standoff point and hold. " +
                           "You can change the values while it holds; it will move to the new point.")
            }

            // ----- How to change flight modes ----------------------------
            QGCLabel {
                text:            qsTr("How to change flight modes")
                font.pointSize:  ScreenTools.largeFontPointSize
                font.bold:       true
            }
            QGCLabel {
                Layout.fillWidth: true
                Layout.leftMargin: _stepIndent
                wrapMode:         Text.WordWrap
                text: qsTr("1. At the top of the Fly view you will see the current flight mode name (for example, \"Hold\").\n\n" +
                           "2. Tap the flight mode name. A list of available modes will open.\n\n" +
                           "3. Press and hold the mode you want. The button fills up while you hold, then the aircraft switches to that mode.\n\n" +
                           "The everyday modes are:\n" +
                           "   • Takeoff — climb straight up and hover.\n" +
                           "   • Land — descend slowly and land where it is.\n" +
                           "   • Safe Recovery — fly back to the launch point.\n" +
                           "   • Standoff — hold at the standoff point (see above).\n" +
                           "   • Engagement — start the engagement run against the target.\n" +
                           "   • Hold — stop and stay in place.\n" +
                           "   • Abort — safely break off and retreat to a safe point.")
            }

            // ----- How to use the camera view ----------------------------
            QGCLabel {
                text:            qsTr("How to use the camera view")
                font.pointSize:  ScreenTools.largeFontPointSize
                font.bold:       true
            }
            QGCLabel {
                Layout.fillWidth: true
                Layout.leftMargin: _stepIndent
                wrapMode:         Text.WordWrap
                text: qsTr("1. The camera view is the small window in the corner. Tap the swap icon to make it the main view.\n\n" +
                           "2. Tap once on the video where you see the target — a green box will appear and the aircraft will start following that spot.\n\n" +
                           "3. If the target moves and the box no longer sits on it, tap the target again to correct.\n\n" +
                           "4. To draw a box around a wider area, click and drag on the video instead of tapping.")
            }

            // ----- If something goes wrong -------------------------------
            QGCLabel {
                text:            qsTr("If something goes wrong")
                font.pointSize:  ScreenTools.largeFontPointSize
                font.bold:       true
            }
            QGCLabel {
                Layout.fillWidth: true
                Layout.leftMargin: _stepIndent
                wrapMode:         Text.WordWrap
                text: qsTr("• If the aircraft does not respond, first switch to \"Hold\" mode so it stays in place while you check.\n\n" +
                           "• If you need to break off immediately, press \"Abort\". The aircraft will fly to a safe recovery point.\n\n" +
                           "• If the battery gets low, switch to \"Safe Recovery\" to return to the launch point.")
            }
        }
    }
}
