import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.components as WorkspaceComponents
import "components"
import "panels" as Panels

// The popup. Top to bottom: a header strip (battery plus screenshot, settings,
// lock and power buttons), the volume and brightness sliders, then a
// two-column grid of toggle pills. A pill's panel drops in directly beneath
// the row that owns it; the Sound panel opens beneath the volume slider.
Item {
    id: full

    required property var app

    readonly property var config: Plasmoid.configuration

    // The open panel, or "". Only ever one: reopening the popup starts
    // collapsed rather than restoring whatever was last expanded.
    property string expandedKey: ""
    property int gridPanelSlot: 0

    // Pills in grid order, before the visibility filter.
    readonly property var tileOrder: ["wired", "bluetooth", "wifi", "vpn", "power", "fan", "nightlight", "awake", "airplane"]
    readonly property var visibleKeys: tileOrder.filter(key => tileVisible(key))

    function tileVisible(key) {
        switch (key) {
        case "wired": return config.showWired;
        case "bluetooth": return config.showBluetooth;
        case "wifi": return config.showWifi;
        case "vpn": return config.showVpn;
        case "power": return config.showPower && app.power.available;
        case "fan": return config.showFan && app.fan.available;
        case "nightlight": return config.showNightLight && app.nightLight.available;
        case "awake": return config.showAwake;
        case "airplane": return config.showAirplane;
        }
        return false;
    }

    function toggleExpansion(key) {
        const target = expandedKey === key ? "" : key;
        if (target === "") {
            // Folding shut: the window stays as tall as it is until the panel
            // has finished, then shrinks once (see windowHeight).
            heldHeight = windowHeight;
        } else if (expandedKey !== "") {
            // Switching panels: drop the old one at once. Two panels
            // animating opposite ways at the same time reads as a glitch.
            collapse();
        }
        if (target !== "" && target !== "audio") {
            gridPanelSlot = visibleKeys.indexOf(target);
        }
        expandedKey = target;
    }

    function collapse() {
        sliderPanel.snap = gridPanel.snap = true;
        expandedKey = "";
        sliderPanel.snap = gridPanel.snap = false;
        heldHeight = 0;
    }

    // The popup window is resized once per open or close, never per frame.
    //
    // Resizing a Plasma popup is expensive on Wayland - a new buffer, the
    // dialog background re-rendered, the blur region recomputed - so following
    // a panel's animation with the window is what made it stutter. Instead the
    // window jumps straight to the height things are heading for, and the
    // animation plays out inside it: opening, the window grows first and the
    // content moves into the room; closing, the window waits (heldHeight) and
    // shrinks when the panel has folded.
    property real heldHeight: 0
    readonly property real settledHeight: column.implicitHeight
        - sliderPanel.implicitHeight - gridPanel.implicitHeight
        + sliderPanel.targetHeight + gridPanel.targetHeight
    readonly property real windowHeight: Math.max(settledHeight, heldHeight)

    readonly property bool panelsSettled: sliderPanel.settled && gridPanel.settled
    onPanelsSettledChanged: {
        if (panelsSettled) {
            heldHeight = 0;
        }
    }

    // A popup on a bottom panel keeps its bottom edge where it is and grows
    // upwards, so that is the edge the content has to hold on to while the
    // window is taller than it. Anywhere else the top edge is the fixed one.
    readonly property bool growsUpward: Plasmoid.location === PlasmaCore.Types.BottomEdge

    Connections {
        target: full.app
        function onExpandedChanged() {
            if (full.app.expanded) {
                // Everything else is live; these are the ones that are read.
                full.app.brightness.refresh();
                full.app.fan.refresh();
                full.app.contrast.scan(false);
            } else {
                full.collapse();
            }
        }
    }

    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.maximumWidth: Kirigami.Units.gridUnit * 28
    Layout.minimumHeight: windowHeight
    Layout.preferredHeight: windowHeight
    Layout.maximumHeight: windowHeight

    SystemPalette {
        id: systemPalette
        colorGroup: SystemPalette.Active
    }
    Style {
        id: look
        // Read off the popup itself, which is visible; see Style.qml for why.
        text: full.Kirigami.Theme.textColor
        systemAccent: systemPalette.accent
    }

    // Test renders (tools/grab.sh) capture this item alone, without the popup
    // window that normally provides the background.
    Rectangle {
        visible: full.app.devGrabPath !== ""
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
    }

    Component {
        id: audioPanel
        Panels.AudioPanel { app: full.app; style: look }
    }
    Component {
        id: wiredPanel
        Panels.WiredPanel { app: full.app; style: look }
    }
    Component {
        id: bluetoothPanel
        Panels.BluetoothPanel { app: full.app; style: look }
    }
    Component {
        id: wifiPanel
        Panels.WifiPanel { app: full.app; style: look }
    }
    Component {
        id: vpnPanel
        Panels.VpnPanel { app: full.app; style: look }
    }
    Component {
        id: powerPanel
        Panels.PowerPanel { app: full.app; style: look }
    }
    Component {
        id: fanPanel
        Panels.FanPanel { app: full.app; style: look }
    }

    ColumnLayout {
        id: column
        width: parent.width
        y: full.growsUpward ? Math.max(0, full.height - implicitHeight) : 0
        spacing: 10

        // Header strip: battery readout on the left, system actions on the right.
        RowLayout {
            spacing: 6

            T.AbstractButton {
                id: batteryChip
                visible: full.app.battery.present
                implicitWidth: chipRow.implicitWidth + 28
                implicitHeight: 32

                // The readout doubles as the way into the power settings.
                Accessible.name: i18n("Battery at %1%. Open power settings", full.app.battery.percent)
                Accessible.role: Accessible.Button
                onClicked: full.app.openSettings("kcm_powerdevilprofilesconfig")

                contentItem: Item {
                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6

                        WorkspaceComponents.BatteryIcon {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            hasBattery: true
                            percent: full.app.battery.percent
                            pluggedIn: full.app.battery.pluggedIn
                        }
                        PlasmaComponents.Label {
                            text: i18nc("battery percentage", "%1%", full.app.battery.percent)
                            textFormat: Text.PlainText
                        }
                    }
                }

                background: Rectangle {
                    radius: height / 2
                    color: batteryChip.pressed ? look.tilePressed
                         : batteryChip.hovered ? look.tileHover : look.tileIdle
                    border.width: batteryChip.visualFocus ? 2 : 0
                    border.color: look.accent
                    Behavior on color {
                        ColorAnimation { duration: look.hoverDuration }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                style: look
                filled: true
                iconName: "applets-screenshooter-symbolic"
                fallbackIconName: "camera-photo-symbolic"
                tooltip: i18n("Take a Screenshot")
                onClicked: full.app.takeScreenshot()
            }
            IconButton {
                style: look
                filled: true
                iconName: "emblem-system-symbolic"
                fallbackIconName: "configure"
                tooltip: i18n("System Settings")
                onClicked: full.app.openSystemSettings()
            }
            IconButton {
                style: look
                filled: true
                iconName: "changes-prevent-symbolic"
                fallbackIconName: "system-lock-screen"
                tooltip: i18n("Lock Screen")
                onClicked: full.app.lockScreen()
            }
            IconButton {
                style: look
                filled: true
                id: powerButton
                iconName: "system-shutdown-symbolic"
                tooltip: i18n("Power")
                onClicked: powerMenu.openRelative()

                // Each entry acts at once: no confirmation screen, no countdown.
                PlasmaExtras.Menu {
                    id: powerMenu
                    visualParent: powerButton
                    placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup

                    PlasmaExtras.MenuItem {
                        text: i18n("Sleep")
                        icon: "system-suspend"
                        visible: full.app.canSuspend
                        onClicked: full.app.suspend()
                    }
                    PlasmaExtras.MenuItem {
                        text: i18n("Restart")
                        icon: "system-reboot"
                        visible: full.app.canReboot
                        onClicked: full.app.reboot()
                    }
                    PlasmaExtras.MenuItem {
                        text: i18n("Shut Down")
                        icon: "system-shutdown"
                        visible: full.app.canShutdown
                        onClicked: full.app.shutDown()
                    }
                }
            }
        }

        // Slider stack: volume (with its device chevron), then one brightness
        // slider per display.
        ColumnLayout {
            // No layout spacing here or in the grid: spacing around a panel
            // would arrive all at once when it turns visible. Every row
            // carries its own bottom margin instead, cancelled after the last.
            spacing: 0
            Layout.bottomMargin: -4

            SliderRow {
                style: look
                Layout.bottomMargin: 4
                visible: full.config.showVolume && full.app.audio.available
                iconName: full.app.audio.icon
                label: i18n("Volume")
                value: full.app.audio.volume
                iconClickable: true
                expandable: true
                onMoved: value => full.app.audio.setVolume(value)
                onIconClicked: full.app.audio.toggleMute()
                onExpandRequested: full.toggleExpansion("audio")
            }

            ExpansionPanel {
                id: sliderPanel
                style: look
                panels: ({ audio: audioPanel })
                panelKey: full.expandedKey === "audio" ? "audio" : ""
                gapAbove: 2
                gapBelow: 6
            }

            Repeater {
                model: full.config.showBrightness ? full.app.brightness.displays : []
                delegate: MonitorRow {
                    required property var modelData

                    style: look
                    Layout.bottomMargin: 4
                    display: modelData
                    monitor: full.config.showMonitorContrast && !modelData.isInternal
                        ? full.app.contrast.monitorFor(modelData.label) : null
                    onContrastCommitted: fraction => full.app.contrast.setContrast(monitor.bus, fraction)
                }
            }
        }

        // The pills, two to a row. Rows and columns are assigned from each
        // pill's place among the visible ones, which leaves the odd rows free
        // for the panel to drop into beneath whichever row owns it.
        GridLayout {
            id: grid
            columns: 2
            uniformCellWidths: true
            columnSpacing: look.pillSpacing
            rowSpacing: 0
            Layout.bottomMargin: -look.pillSpacing

            component Pill: QuickTile {
                required property string key
                readonly property int slot: full.visibleKeys.indexOf(key)

                style: look
                bodyToggles: full.config.bodyToggles
                visible: slot >= 0
                Layout.bottomMargin: look.pillSpacing
                Layout.row: 2 * Math.floor(Math.max(0, slot) / 2)
                Layout.column: Math.max(0, slot) % 2
                onExpandRequested: full.toggleExpansion(key)
            }

            Pill {
                key: "wired"
                title: i18n("Wired")
                iconName: "network-wired-symbolic"
                expandable: true
                active: full.app.network.wiredActive
                subtitle: active ? full.app.network.wiredName
                        : full.app.network.wiredAvailable ? i18n("Not connected") : i18n("No adapter")
                onToggled: full.app.network.setWired(!active)
            }
            Pill {
                key: "bluetooth"
                title: i18n("Bluetooth")
                iconName: "bluetooth-symbolic"
                fallbackIconName: "network-bluetooth"
                expandable: true
                active: full.app.bluetooth.powered
                subtitle: full.app.bluetooth.summary
                onToggled: full.app.bluetooth.setEnabled(!active)
            }
            Pill {
                key: "wifi"
                title: i18n("Wi-Fi")
                iconName: "network-wireless-symbolic"
                expandable: true
                active: full.app.network.wifiEnabled
                subtitle: !active ? ""
                        : full.app.network.wifiName !== "" ? full.app.network.wifiName
                        : full.app.network.wifiConnecting ? i18n("Connecting…") : ""
                onToggled: full.app.network.setWifi(!active)
            }
            Pill {
                key: "vpn"
                title: i18n("VPN")
                iconName: "network-vpn-symbolic"
                expandable: true
                active: full.app.network.vpnActive
                subtitle: active ? full.app.network.vpnName
                        : full.app.network.vpnCount > 0 ? i18n("Not connected") : i18n("None configured")
                onToggled: full.app.network.setVpn(!active)
            }
            Pill {
                key: "power"
                title: i18n("Power Mode")
                iconName: full.app.power.icon(full.app.power.current)
                fallbackIconName: "battery-profile-balanced"
                toggleable: false
                expandable: true
                // Performance is the one profile worth flagging at a glance.
                active: full.app.power.current === "performance"
                subtitle: full.app.power.label(full.app.power.current)
            }
            Pill {
                key: "fan"
                title: i18n("Fan Curve")
                iconName: "sensors-fan-symbolic"
                fallbackIconName: "weather-windy-symbolic"
                toggleable: false
                expandable: true
                subtitle: full.app.fan.summary
            }
            Pill {
                key: "nightlight"
                title: i18n("Night Light")
                iconName: "night-light-symbolic"
                fallbackIconName: "redshift-status-on"
                active: full.app.nightLight.active
                subtitle: !active ? "" : full.app.nightLight.running ? i18n("On") : i18n("Waiting for sunset")
                onToggled: full.app.nightLight.setEnabled(!active)
            }
            Pill {
                key: "awake"
                title: i18n("Keep Awake")
                iconName: "preferences-desktop-screensaver-symbolic"
                fallbackIconName: "system-suspend-inhibited"
                active: full.app.keepAwake.active
                subtitle: active ? i18n("No timeout") : ""
                onToggled: full.app.keepAwake.setActive(!active)
            }
            Pill {
                key: "airplane"
                title: i18n("Airplane Mode")
                iconName: "airplane-mode-symbolic"
                fallbackIconName: "network-flightmode-on"
                active: full.app.network.airplaneMode
                onToggled: full.app.network.setAirplane(!active)
            }

            ExpansionPanel {
                id: gridPanel
                style: look
                panels: ({
                    wired: wiredPanel,
                    bluetooth: bluetoothPanel,
                    wifi: wifiPanel,
                    vpn: vpnPanel,
                    power: powerPanel,
                    fan: fanPanel,
                })
                panelKey: full.expandedKey !== "audio" ? full.expandedKey : ""
                gapBelow: look.pillSpacing
                Layout.row: 2 * Math.floor(full.gridPanelSlot / 2) + 1
                Layout.column: 0
                Layout.columnSpan: 2
            }
        }
    }
}
