import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM
import "../components"

PanelBody {
    id: body

    title: i18n("Wi-Fi")
    iconName: "network-wireless-symbolic"
    footerText: i18n("Wi-Fi Settings")
    settingsModule: "kcm_networkmanagement"
    busy: app.network.scanning

    // How many networks to list. The model is already sorted with the
    // connected one first and the rest by signal, and merges the per-band,
    // per-AP duplicates of one SSID, so this is simply the best few.
    readonly property int limit: 6

    function signalIcon(strength) {
        if (strength >= 80) {
            return "network-wireless-signal-excellent-symbolic";
        }
        if (strength >= 55) {
            return "network-wireless-signal-good-symbolic";
        }
        if (strength >= 30) {
            return "network-wireless-signal-ok-symbolic";
        }
        return strength >= 5 ? "network-wireless-signal-weak-symbolic" : "network-wireless-signal-none-symbolic";
    }

    Component.onCompleted: app.network.requestScan()

    Repeater {
        id: list
        model: body.app.network.wifiConnections
        delegate: PanelRow {
            required property var model
            required property int index
            readonly property bool up: model.ConnectionState === PlasmaNM.Enums.Activated

            visible: index < body.limit
            style: body.style
            iconName: body.signalIcon(model.Signal)
            label: model.ItemUniqueName
            current: false
            busy: model.ConnectionState === PlasmaNM.Enums.Activating
                  || model.ConnectionState === PlasmaNM.Enums.Deactivating
            actionText: up ? i18n("Disconnect") : i18n("Connect")
            onActivated: body.app.network.setConnection(model, !up)
        }
    }

    PanelNote {
        style: body.style
        visible: list.count === 0
        text: body.app.network.wifiEnabled ? i18n("No networks found") : i18n("Wi-Fi is switched off")
    }
}
