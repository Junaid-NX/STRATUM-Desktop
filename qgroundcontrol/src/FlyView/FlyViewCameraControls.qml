import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// STRATUM camera / gimbal control cluster. Self-contained: every button drives
// QGroundControl.videoManager.sendCameraAction() directly (the YunZhuo/Skydroid
// TOP protocol over UDP), mirroring the UAV-VAS web UI camera panel:
//   * TV / IR feed select
//   * Pan / Tilt cross (arrow glyphs, hold-to-move -> stop on release)
//   * Zoom - / +
//   * Capture / Record (toggle) / Track (toggle)
//   * False-colour palette
//
// Reused in two places (FlyViewDropperPanel camera section, and the maximized
// video overlay in FlyView) so the controls follow the camera when it is the
// maximized window and fold back into the dropper when the map is maximized.
Item {
    id: root

    // overlayMode: translucent card drawn over the live video (maximized camera).
    // Otherwise it renders flush for embedding inside the dropper panel.
    property bool overlayMode: false
    // compact: tighter spacing / fonts for the picture-in-picture / panel context.
    property bool compact: false
    // daggerMode: when true (Dagger airframe with C12), TV/IR toggle drives the
    // daggerC12TvRtspUrl / daggerC12IrRtspUrl settings instead of tvRtspUrl / irRtspUrl.
    property bool daggerMode: false

    // Emitted after every command so the host (dropper panel / overlay) can show feedback.
    signal statusMessage(string text)

    readonly property var _vs: QGroundControl.settingsManager.videoSettings
    // Profile-scoped URL pair. Kept as readonly properties so QML change-tracking follows
    // the daggerMode flag automatically.
    readonly property string _tvUrl: daggerMode ? _vs.daggerC12TvRtspUrl.rawValue : _vs.tvRtspUrl.rawValue
    readonly property string _irUrl: daggerMode ? _vs.daggerC12IrRtspUrl.rawValue : _vs.irRtspUrl.rawValue
    // Active feed is derived from which stored URL the live rtspUrl currently matches,
    // so the dropper panel and the video overlay always show the same TV/IR state.
    readonly property bool _feedIrActive: _irUrl !== "" && _vs.rtspUrl.rawValue === _irUrl
    property bool _recActive:    false
    property bool _trackActive:  false

    readonly property color _accent:    "#3DFFA6"
    readonly property color _accentDim:  "#1FB97D"
    readonly property real  _btnHeight:  ScreenTools.defaultFontPixelHeight * (compact ? 1.9 : 2.3)
    readonly property real  _spacing:    ScreenTools.defaultFontPixelWidth * 0.4
    // Inner padding — only in overlay mode (the bordered card over the video).
    readonly property real  _pad:        overlayMode ? ScreenTools.defaultFontPixelWidth * 0.75 : 0

    // Include the padding so the content is never compressed / clipped by the border.
    implicitWidth:  contentColumn.implicitWidth + (_pad * 2)
    implicitHeight: contentColumn.implicitHeight + (_pad * 2)

    function _send(cameraAction) {
        const sent = QGroundControl.videoManager.sendCameraAction(cameraAction)
        if (!sent) {
            root.statusMessage(qsTr("Camera command failed"))
        }
        return sent
    }

    function _selectFeed(feed) {
        const url = (feed === "IR") ? _irUrl : _tvUrl
        if (!url) {
            root.statusMessage(qsTr("No %1 URL set — configure it in Application Settings ▸ Video").arg(feed))
            return
        }
        // Ensure the RTSP source is active, then point it at the chosen feed. Writing
        // rtspUrl restarts the stream (VideoManager listens on its rawValueChanged), so
        // the video swaps between the TV and IR URLs — matching the web UI TV/IR buttons.
        if (_vs.videoSource.rawValue !== _vs.rtspVideoSource) {
            _vs.videoSource.rawValue = _vs.rtspVideoSource
        }
        _vs.rtspUrl.rawValue = url
        root.statusMessage(qsTr("%1 feed selected").arg(feed))
    }

    function _toggleRec() {
        _recActive = !_recActive
        if (_send(_recActive ? "rec-start" : "rec-stop")) {
            root.statusMessage(_recActive ? qsTr("● Recording started") : qsTr("■ Recording stopped"))
        }
    }

    // Timer used by _toggleTrack to gap SUM 01 (arm tracker) and GOT (feed target).
    // Some C12 firmware drops GOT when it arrives back-to-back with SUM 01.
    Timer {
        id: _trackFeedTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (!root._send("track-center")) {
                root._trackActive = false
                root.statusMessage(qsTr("Tracking start failed (GOT)"))
                return
            }
            root.statusMessage(qsTr("◎ Tracker armed → target 640,360"))
        }
    }

    function _toggleTrack() {
        _trackActive = !_trackActive
        if (_trackActive) {
            // C12 protocol §3.3.4→§3.3.5 order: SUM 01 arms tracker mode ("Tracking
            // acknowledged"), then GOT feeds the target pixel on the 1280×720 frame.
            if (!_send("track-ack")) {
                _trackActive = false
                return
            }
            _trackFeedTimer.restart()
        } else {
            if (_send("track-stop")) {
                root.statusMessage(qsTr("✕ Tracking off"))
            } else {
                _trackActive = true
            }
        }
    }

    // Hold-to-move gimbal button: repeats the pan/tilt command while held, sends
    // "stop" on release (matches web UI camStart / camStop, 200 ms interval).
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

    // Palette swatch: Canvas-painted horizontal linear gradient inside a rounded
    // frame. Uses the same _send() plumbing as everything else — this is a UI
    // rework only, no command changes.
    component PaletteChip : Item {
        id: chip
        property string chipText
        property string chipCode
        property var stops: []
        property bool selected: false
        signal chipClicked

        implicitWidth:  ScreenTools.defaultFontPixelWidth * (root.compact ? 2.8 : 3.4)
        implicitHeight: root._btnHeight * 0.85

        Rectangle {
            id: chipFrame
            anchors.fill: parent
            radius: 4
            color: "transparent"
            border.color: chip.selected
                          ? root._accent
                          : (chipMouse.containsMouse ? root._accentDim : Qt.rgba(1, 1, 1, 0.18))
            border.width: chip.selected ? 2 : 1
            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        Canvas {
            id: swatch
            anchors.fill: chipFrame
            anchors.margins: chip.selected ? 3 : 2
            antialiasing: true
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width
                const h = height
                const r = 3
                ctx.beginPath()
                ctx.moveTo(r, 0)
                ctx.lineTo(w - r, 0)
                ctx.quadraticCurveTo(w, 0, w, r)
                ctx.lineTo(w, h - r)
                ctx.quadraticCurveTo(w, h, w - r, h)
                ctx.lineTo(r, h)
                ctx.quadraticCurveTo(0, h, 0, h - r)
                ctx.lineTo(0, r)
                ctx.quadraticCurveTo(0, 0, r, 0)
                ctx.closePath()
                const g = ctx.createLinearGradient(0, 0, w, 0)
                const s = chip.stops || []
                for (let i = 0; i < s.length; i++) {
                    g.addColorStop(s[i][0], s[i][1])
                }
                ctx.fillStyle = g
                ctx.fill()
            }
            onWidthChanged:  requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: chip
                function onSelectedChanged() { swatch.requestPaint() }
                function onStopsChanged()    { swatch.requestPaint() }
            }
        }

        ToolTip.visible: chipMouse.containsMouse
        ToolTip.text:    chip.chipText
        ToolTip.delay:   400

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.chipClicked()
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

        // ---- Feed select: TV / IR ------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: root._spacing

            QGCButton {
                text: qsTr("TV")
                implicitHeight: root._btnHeight
                Layout.fillWidth: true
                backRadius: ScreenTools.defaultBorderRadius
                showBorder: true
                primary: !root._feedIrActive
                onClicked: root._selectFeed("TV")
            }
            QGCButton {
                text: qsTr("IR")
                implicitHeight: root._btnHeight
                Layout.fillWidth: true
                backRadius: ScreenTools.defaultBorderRadius
                showBorder: true
                primary: root._feedIrActive
                onClicked: root._selectFeed("IR")
            }
        }

        // ---- Pan / Tilt cross (arrow glyphs, hold-to-move) -----------------
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: root._spacing
            rowSpacing: root._spacing

            Item { Layout.fillWidth: true; Layout.preferredHeight: root._btnHeight }
            PtzButton { text: qsTr("▲"); ptzAction: "pan-up" }
            Item { Layout.fillWidth: true; Layout.preferredHeight: root._btnHeight }

            PtzButton { text: qsTr("◄"); ptzAction: "tilt-left" }
            QGCButton {
                text: qsTr("⊙")
                implicitHeight: root._btnHeight
                Layout.fillWidth: true
                onClicked: { if (root._send("center")) root.statusMessage(qsTr("Gimbal centred")) }
            }
            PtzButton { text: qsTr("►"); ptzAction: "tilt-right" }

            Item { Layout.fillWidth: true; Layout.preferredHeight: root._btnHeight }
            PtzButton { text: qsTr("▼"); ptzAction: "pan-down" }
            Item { Layout.fillWidth: true; Layout.preferredHeight: root._btnHeight }
        }

        // ---- Zoom ----------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: root._spacing

            QGCLabel {
                text: qsTr("ZOOM")
                color: root._accentDim
                font.pointSize: ScreenTools.smallFontPointSize
                Layout.alignment: Qt.AlignVCenter
            }
            QGCButton {
                text: qsTr("−")
                implicitHeight: root._btnHeight
                Layout.fillWidth: true
                onClicked: { if (root._send("zoom-out")) root.statusMessage(qsTr("Zoom out")) }
            }
            QGCButton {
                text: qsTr("+")
                implicitHeight: root._btnHeight
                Layout.fillWidth: true
                onClicked: { if (root._send("zoom-in")) root.statusMessage(qsTr("Zoom in")) }
            }
        }

        // ---- Media: Capture / Record --------------------------------------
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

        // ---- Track ---------------------------------------------------------
        QGCButton {
            text: root._trackActive ? qsTr("✕ Stop Track") : qsTr("◎ Track")
            implicitHeight: root._btnHeight
            Layout.fillWidth: true
            primary: root._trackActive
            onClicked: root._toggleTrack()
        }

        // ---- False-colour palette (chip strip) ----------------------------
        ColumnLayout {
            id: paletteBlock
            Layout.fillWidth: true
            spacing: root._spacing * 0.6

            property string currentCode: "palette-off"
            property string currentName: qsTr("Normal")

            // (name, code, gradient stops) — stops are [position, cssColor] pairs.
            // Gradients are hand-picked to resemble the C12's actual thermal LUTs.
            readonly property var paletteData: [
                { name: qsTr("Normal"),        code: "palette-off", stops: [[0.0, "#5a5a5a"], [1.0, "#d5d5d5"]] },
                { name: qsTr("White Hot"),     code: "palette-01",  stops: [[0.0, "#000000"], [1.0, "#ffffff"]] },
                { name: qsTr("Black Hot"),     code: "palette-0b",  stops: [[0.0, "#ffffff"], [1.0, "#000000"]] },
                { name: qsTr("Red Hot"),       code: "palette-08",  stops: [[0.0, "#000000"], [0.55, "#b30000"], [1.0, "#ffe066"]] },
                { name: qsTr("Iron Red"),      code: "palette-04",  stops: [[0.0, "#000000"], [0.35, "#4d0033"], [0.6, "#c8321e"], [0.85, "#ffd85c"], [1.0, "#ffffff"]] },
                { name: qsTr("Rainbow"),       code: "palette-05",  stops: [[0.0, "#5b005b"], [0.2, "#0033ff"], [0.4, "#00cccc"], [0.6, "#33cc33"], [0.8, "#ffcc00"], [1.0, "#ff2b2b"]] },
                { name: qsTr("Glimmer Night"), code: "palette-06",  stops: [[0.0, "#001a1a"], [0.5, "#00554d"], [1.0, "#3dffa6"]] },
                { name: qsTr("Aurora"),        code: "palette-07",  stops: [[0.0, "#1a0033"], [0.4, "#5900b3"], [0.7, "#00cccc"], [1.0, "#33ff99"]] },
                { name: qsTr("Sepia"),         code: "palette-03",  stops: [[0.0, "#2b1a00"], [0.5, "#a86a2c"], [1.0, "#f2e0b3"]] },
                { name: qsTr("Jungle"),        code: "palette-09",  stops: [[0.0, "#002200"], [0.5, "#4d9900"], [1.0, "#e5ff33"]] },
                { name: qsTr("Medical"),       code: "palette-0a",  stops: [[0.0, "#000000"], [0.5, "#00993d"], [1.0, "#e60000"]] },
                { name: qsTr("Glory Hot"),     code: "palette-0c",  stops: [[0.0, "#000000"], [0.3, "#3c008a"], [0.55, "#c8321e"], [0.8, "#ffe066"], [1.0, "#ffffff"]] }
            ]

            RowLayout {
                Layout.fillWidth: true
                spacing: root._spacing

                QGCLabel {
                    text: qsTr("PALETTE")
                    color: root._accentDim
                    font.pointSize: ScreenTools.smallFontPointSize
                    font.letterSpacing: 1.5
                }
                Item { Layout.fillWidth: true }
                QGCLabel {
                    text: paletteBlock.currentName
                    color: root._accent
                    font.pointSize: ScreenTools.smallFontPointSize
                    font.bold: true
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: root._spacing

                Repeater {
                    model: paletteBlock.paletteData
                    delegate: PaletteChip {
                        required property var modelData
                        chipText: modelData.name
                        chipCode: modelData.code
                        stops:    modelData.stops
                        selected: paletteBlock.currentCode === modelData.code
                        onChipClicked: {
                            if (root._send(modelData.code)) {
                                paletteBlock.currentCode = modelData.code
                                paletteBlock.currentName = modelData.name
                                root.statusMessage(qsTr("Palette: %1").arg(modelData.name))
                            }
                        }
                    }
                }
            }
        }
    }
}
