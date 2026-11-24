// page 4: user, computer name, password - (c) 2026 34 & Claude
import QtQuick
import "../components"

Item {
    property var app
    property bool userTouched: false

    function suggestUser(name) {
        var u = name.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/ß/g, "ss")
        u = u.split(" ")[0].replace(/[^a-z0-9_-]/g, "")
        return u.replace(/^[0-9-]+/, "")
    }

    Column {
        anchors.centerIn: parent
        spacing: 16
        Text { text: app.t("user_title"); color: Theme.text; font.family: Theme.font; font.pixelSize: 34; font.weight: Font.Bold }
        Row {
            spacing: 28
            Column {
                spacing: 14
                Field { label: app.t("fullname"); text: app.fullname
                        onEdited: { app.fullname = text; if (!userTouched) app.username = suggestUser(text) } }
                Field { label: app.t("username"); text: app.username
                        bad: app.username !== "" && !/^[a-z_][a-z0-9_-]*$/.test(app.username)
                        hint: bad ? app.t("err_username") : ""
                        onEdited: { userTouched = true; app.username = text } }
                Field { label: app.t("hostname"); text: app.hostname
                        bad: !/^[A-Za-z0-9][A-Za-z0-9-]*$/.test(app.hostname)
                        hint: bad ? app.t("err_hostname") : ""
                        onEdited: app.hostname = text }
            }
            Column {
                spacing: 14
                Field { label: app.t("password"); echoMode: TextInput.Password; text: app.password
                        hint: app.password !== "" && app.password.length < 6 ? app.t("pw_short") : ""
                        onEdited: app.password = text }
                Field { label: app.t("password2"); echoMode: TextInput.Password; text: app.password2
                        bad: app.password2 !== "" && app.password2 !== app.password
                        hint: bad ? app.t("pw_mismatch") : ""
                        onEdited: app.password2 = text }
            }
        }
    }
}
