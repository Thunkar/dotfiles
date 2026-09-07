// Self-contained SDDM greeter for the dotfiles theme.
// No external component files, no graphical-effects dependency —
// just QtQuick + QtQuick.Controls so it works on a bare Qt6 install.
//
// All colors/fonts come from theme.conf (rendered from theme/colors.env).
//
// Multi-monitor: SDDM instantiates this file once per screen and gives
// keyboard focus to the window on the *primary* screen (which the theme's
// Xsetup script points at the Hyprland primary output). Only that instance
// draws the clock, login card and power buttons; the others show just the
// blurred wallpaper. Without this every screen had its own password field
// and the visible one was not the one receiving keystrokes.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: config.ColorBase

    property color cAccent:   config.ColorAccent
    property color cAccentFg: config.ColorAccentFg
    property color cText:     config.ColorText
    property color cSubtext:  config.ColorSubtext
    property color cSurface0: config.ColorSurface0
    property color cSurface1: config.ColorSurface1
    property color cOverlay:  config.ColorOverlay
    property color cError:    config.ColorError
    property color cCrust:    config.ColorCrust
    property string fontFamily: config.Font
    property int    fontSize:   parseInt(config.FontSize)

    // `primaryScreen` is a context property set by SDDM per view. Fall back
    // to "yes" if it is ever missing so a login is always possible.
    readonly property bool isMain: (typeof primaryScreen === "undefined") ? true : primaryScreen

    // ── Live clock ───────────────────────────────────────────────
    function pad(n) { return n < 10 ? "0" + n : "" + n }
    property string timeStr: ""
    property string dateStr: ""
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            root.timeStr = root.pad(d.getHours()) + ":" + root.pad(d.getMinutes())
            root.dateStr = Qt.formatDate(d, "dddd, MMMM d")
        }
    }

    // ── Background (pre-blurred wallpaper, generated at install) ─────
    // background.png is produced by apply.sh's ensure_sddm_theme from
    // the desktop wallpaper (magick blur+dim), so no QML blur effect /
    // GraphicalEffects dependency is needed. Falls back to ColorBase.
    Image {
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: status === Image.Ready
    }
    // Dark scrim over the wallpaper for text legibility.
    Rectangle {
        anchors.fill: parent
        color: config.ColorBase
        opacity: 0.45
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 28
        visible: root.isMain

        // Clock
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.timeStr
            color: root.cText
            font.family: root.fontFamily
            font.pixelSize: 96
            font.bold: true
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.dateStr
            color: root.cSubtext
            font.family: root.fontFamily
            font.pixelSize: 22
        }

        Item { Layout.preferredHeight: 20 }   // spacer

        // ── Login card ───────────────────────────────────────────
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 380
            Layout.preferredHeight: userCol.implicitHeight + 56
            radius: 16
            color: config.ColorMantle
            border.color: root.cSurface1
            border.width: 1

            ColumnLayout {
                id: userCol
                anchors.centerIn: parent
                width: parent.width - 56
                spacing: 16

                // Username
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: userModel.lastUser !== "" ? userModel.lastUser : "user"
                    color: root.cText
                    font.family: root.fontFamily
                    font.pixelSize: 16
                    font.bold: true
                }

                // Password field
                TextField {
                    id: pw
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: "Password"
                    color: root.cText
                    placeholderTextColor: root.cOverlay
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize
                    focus: root.isMain
                    leftPadding: 14
                    rightPadding: 14
                    topPadding: 12
                    bottomPadding: 12
                    background: Rectangle {
                        radius: 10
                        color: root.cSurface0
                        border.color: pw.activeFocus ? root.cAccent : root.cSurface1
                        border.width: 2
                        implicitHeight: 46
                    }
                    onAccepted: sddm.login(
                        userModel.lastUser, pw.text, sessionModel.lastIndex)
                    Keys.onEscapePressed: pw.text = ""
                }

                // Login button
                Button {
                    Layout.fillWidth: true
                    text: "Login"
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize
                    contentItem: Text {
                        text: parent.text
                        color: root.cAccentFg
                        font: parent.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 10
                        color: parent.down ? Qt.darker(root.cAccent, 1.15) : root.cAccent
                        implicitHeight: 42
                    }
                    onClicked: sddm.login(
                        userModel.lastUser, pw.text, sessionModel.lastIndex)
                }

                // Error / status message
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    id: errLabel
                    text: ""
                    color: root.cError
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    visible: text !== ""
                }
            }
        }
    }

    // ── Power controls (bottom-right) ────────────────────────────
    RowLayout {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 18
        visible: root.isMain

        Button {
            text: "⏻"
            flat: true
            font.pixelSize: 22
            contentItem: Text {
                text: parent.text; color: root.cError; font: parent.font
                horizontalAlignment: Text.AlignHCenter
            }
            background: Item {}
            onClicked: sddm.powerOff()
        }
        Button {
            text: ""
            flat: true
            font.family: root.fontFamily
            font.pixelSize: 20
            contentItem: Text {
                text: parent.text; color: root.cSubtext; font: parent.font
                horizontalAlignment: Text.AlignHCenter
            }
            background: Item {}
            onClicked: sddm.reboot()
        }
    }

    // ── SDDM signal wiring ───────────────────────────────────────
    Connections {
        target: sddm
        function onLoginFailed() {
            errLabel.text = "Login failed"
            pw.text = ""
            pw.focus = true
        }
        function onLoginSucceeded() {
            errLabel.text = ""
        }
    }

    Timer {
        interval: 300; running: root.isMain; repeat: false
        onTriggered: {
            if (root.Window.window) root.Window.window.requestActivate()
            pw.forceActiveFocus()
        }
    }

    Component.onCompleted: if (root.isMain) pw.forceActiveFocus()
}
