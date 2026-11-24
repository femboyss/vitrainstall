// vitrainstall - the Vitra installer
// (c) 2026 34 & Claude - GPL-3.0-or-later
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "components"
import "pages"
import "Strings.js" as S

Window {
    id: root
    width: 1280
    height: 800
    visible: true
    visibility: startWindowed ? Window.Windowed : Window.FullScreen
    title: "vitrainstall"
    color: Theme.bg

    // ---------------------------------------------------------------- choices
    property string language: startLanguage
    property string platform: ""
    property string keyboard: language === "de" ? "at" : "us"
    property string timezone: "UTC"
    property var disk: null
    property string filesystem: "btrfs"
    property string gfxDriver: "All open-source"
    property string fullname: ""
    property string username: ""
    property string hostname: "vitra"
    property string password: ""
    property string password2: ""
    property bool wipeConfirmed: false
    property bool installOk: false
    property string installError: ""
    property int page: 0
    readonly property int pageCount: 8

    function t(key) { return S.get(language, key) }
    function tf(key, a) { return S.get(language, key).replace("%1", a) }

    function choices() {
        return {
            language: language, platform: platform || "linux", keyboard: keyboard, timezone: timezone,
            disk: disk ? disk.path : "", diskSize: disk ? disk.size : 0, sectorSize: disk ? disk.sectorSize : 512,
            filesystem: filesystem, gfxDriver: gfxDriver, hostname: hostname, fullname: fullname,
            username: username, password: password, uefi: backend.isUefi()
        }
    }

    // can we leave the current page?
    function pageOk(p) {
        switch (p) {
        case 1: return platform !== ""
        case 3: return disk !== null && wipeConfirmed
        case 4: return username !== "" && password !== "" && password === password2 && hostname !== ""
                       && backend.check(choices()) === ""
        default: return true
        }
    }

    function go(p) { page = Math.max(0, Math.min(pageCount - 1, p)) }

    Component.onCompleted: {
        timezone = backend.guessTimezone()
        gfxDriver = backend.guessGfxDriver()
        if (startLite) Theme.lite = true
        else if (shotDir === "") fpsWarmup.start()
    }

    // ---------------------------------------------------------------- lite mode probe
    // The background moves all the time, so a fast machine draws ~60 frames per second.
    // Under ~24 (software rendering in a VM, no GPU driver yet) the effects go off.
    property int frames: 0
    onFrameSwapped: frames++
    Timer { id: fpsWarmup; interval: 3000; onTriggered: { root.frames = 0; fpsMeasure.start() } }
    Timer { id: fpsMeasure; interval: 2000
            onTriggered: { if (root.frames / 2 < 24) Theme.lite = true
                           console.log("vitrainstall: " + (root.frames / 2) + " fps, lite mode " + Theme.lite) } }

    // ---------------------------------------------------------------- look
    Backdrop { anchors.fill: parent }

    // no bar until the platform is picked; then a preview of "your" bar
    PlatformBar {
        anchors.fill: parent
        platform: root.platform
        opacity: root.platform !== "" && root.page >= 2 ? 1 : 0
        Behavior on opacity { enabled: !Theme.lite; NumberAnimation { duration: 500 } }
        z: 1
    }

    Rectangle { // test mode banner
        visible: backend.testMode
        z: 5
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.platform === "mac" || root.platform === "linux" ? 56 : 12
        width: tm.implicitWidth + 28; height: 26; radius: 13
        color: Qt.rgba(1, 0.36, 0.45, 0.18); border.color: Theme.danger
        Text { id: tm; anchors.centerIn: parent; text: root.t("test_mode"); color: Theme.danger
               font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Bold }
    }

    StackLayout {
        id: stack
        anchors.fill: parent
        anchors.topMargin: 70
        anchors.bottomMargin: 120
        currentIndex: root.page
        WelcomePage { app: root }
        PlatformPage { app: root }
        KeyboardPage { app: root }
        DiskPage { app: root }
        UserPage { app: root }
        SummaryPage { app: root }
        InstallPage { app: root }
        DonePage { app: root }
    }

    // ---------------------------------------------------------------- bottom: steps + navigation
    Item {
        id: nav
        visible: root.page >= 1 && root.page <= 4
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.bottomMargin: root.platform === "windows" ? 66 : 28
        height: 60
        Button2 { anchors.left: parent.left; anchors.leftMargin: 48; anchors.verticalCenter: parent.verticalCenter
                  kind: "ghost"; text: root.t("back"); onClicked: root.go(root.page - 1) }
        Row {
            anchors.centerIn: parent; spacing: 8
            Repeater {
                model: 5
                Rectangle {
                    width: index + 1 === root.page ? 28 : 8; height: 8; radius: 4
                    color: index + 1 <= root.page ? Theme.accent : Qt.rgba(1, 1, 1, 0.2)
                    Behavior on width { NumberAnimation { duration: 200 } }
                }
            }
        }
        Button2 { visible: root.page < 5
                  anchors.right: parent.right; anchors.rightMargin: 48; anchors.verticalCenter: parent.verticalCenter
                  text: root.t("next"); enabled2: root.pageOk(root.page); onClicked: root.go(root.page + 1) }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.platform === "windows" && root.page >= 2 ? 52 : 8
        text: "vitrainstall " + backend.version + "  ·  (c) 2026 34 & Claude"
        color: Qt.rgba(1, 1, 1, 0.3); font.family: Theme.font; font.pixelSize: 11
    }

    // ---------------------------------------------------------------- screenshots (--shot)
    property int shotIndex: 0
    function startShots() {
        language = startLanguage
        platform = "windows"; keyboard = "de"; timezone = "Europe/Vienna"
        var d = backend.disks(); disk = d.length ? d[0] : null; wipeConfirmed = true
        fullname = "Stefan"; username = "stefan"; hostname = "vitra-pc"; password = "test1234"; password2 = "test1234"
        platform = ""
        shotIndex = 0
        shotTimer.start()
    }
    Timer {
        id: shotTimer
        interval: root.shotIndex === 7 ? 9500 : 900
        onTriggered: {
            if (root.shotIndex === 2) root.platform = "windows"
            if (root.shotIndex < 7) root.page = root.shotIndex
            shotGrab.start()
        }
    }
    Timer {
        id: shotGrab
        interval: 700
        onTriggered: {
            var name = shotDir + "/page-" + root.shotIndex + ".png"
            root.contentItem.grabToImage(function(r) {
                r.saveToFile(name)
                root.shotIndex++
                if (root.shotIndex === 6) backend.install(root.choices())
                if (root.shotIndex < 8) shotTimer.start(); else backend.quit()
            })
        }
    }
}
