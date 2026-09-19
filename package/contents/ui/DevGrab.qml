import QtQuick
import org.kde.plasma.private.sessions as Sessions

// Development aid: renders the popup to an image and quits. Loaded only when
// the process was started with a `qs-grab=<path>` argument (see main.qml).
// An optional `qs-expand=<key>` opens that panel first, e.g. qs-expand=wifi.
Item {
    id: grab

    property var plasmoidItem: null

    readonly property string expandKey: {
        const arg = Qt.application.arguments.find(a => a.startsWith("qs-expand="));
        return arg ? arg.slice("qs-expand=".length) : "";
    }

    // `qs-toggle=nightlight|awake` flips that setting first, to exercise the
    // backends that have side effects without clicking through a real popup.
    readonly property string toggleKey: {
        const arg = Qt.application.arguments.find(a => a.startsWith("qs-toggle="));
        return arg ? arg.slice("qs-toggle=".length) : "";
    }

    // `qs-check-config` loads every settings page once and reports QML errors,
    // since the pages are otherwise only compiled when the dialog opens.
    Component.onCompleted: {
        if (Qt.application.arguments.includes("qs-check-enums")) {
            console.log("qs-check-enums: ConfirmationMode.Skip =", Sessions.SessionManagement.ConfirmationMode.Skip,
                        "Default =", Sessions.SessionManagement.ConfirmationMode.Default);
        }
        if (!Qt.application.arguments.includes("qs-check-config")) {
            return;
        }
        for (const page of ["ConfigPills", "ConfigAppearance", "ConfigSliders", "ConfigBehaviour"]) {
            const component = Qt.createComponent("config/" + page + ".qml");
            if (component.status !== Component.Ready) {
                console.warn("qs-check-config:", page, "FAILED:", component.errorString());
                continue;
            }
            const object = component.createObject(grab, { visible: false });
            console.log("qs-check-config:", page, object ? "ok" : "could not be created");
            if (object) {
                object.destroy();
            }
        }
    }

    Timer {
        interval: 700
        running: grab.plasmoidItem !== null && grab.toggleKey !== ""
        onTriggered: {
            const app = grab.plasmoidItem;
            if (grab.toggleKey === "nightlight") {
                app.nightLight.setEnabled(!app.nightLight.active);
            } else if (grab.toggleKey === "awake") {
                app.keepAwake.setActive(!app.keepAwake.active);
            }
        }
    }

    Timer {
        // After the live backends have reported their first state.
        interval: 900
        running: grab.plasmoidItem !== null && grab.expandKey !== ""
        onTriggered: {
            const target = grab.plasmoidItem.fullRepresentationItem;
            if (target) {
                target.toggleExpansion(grab.expandKey);
            }
        }
    }

    // `qs-collapse` closes the panel again 700 ms after qs-expand opened it, to
    // exercise the closing animation as well.
    Timer {
        interval: 1600
        running: grab.plasmoidItem !== null && grab.expandKey !== "" && Qt.application.arguments.includes("qs-collapse")
        onTriggered: {
            const target = grab.plasmoidItem.fullRepresentationItem;
            if (target) {
                target.toggleExpansion(grab.expandKey);
            }
        }
    }

    // `qs-switch=<key>` opens a second panel 700 ms after qs-expand opened the
    // first, to exercise switching from one panel straight to another.
    readonly property string switchKey: {
        const arg = Qt.application.arguments.find(a => a.startsWith("qs-switch="));
        return arg ? arg.slice("qs-switch=".length) : "";
    }
    Timer {
        interval: 1600
        running: grab.plasmoidItem !== null && grab.expandKey !== "" && grab.switchKey !== ""
        onTriggered: {
            const target = grab.plasmoidItem.fullRepresentationItem;
            if (target) {
                target.toggleExpansion(grab.switchKey);
            }
        }
    }

    // `qs-delay=<ms>` waits longer before grabbing, for the slow readers
    // (ddcutil takes a few seconds to find a monitor).
    readonly property int delay: {
        const arg = Qt.application.arguments.find(a => a.startsWith("qs-delay="));
        return arg ? parseInt(arg.slice("qs-delay=".length), 10) || 2000 : 2000;
    }

    Timer {
        // Long enough for the backends, and for a panel to finish unfolding.
        interval: grab.delay
        running: grab.plasmoidItem !== null
        onTriggered: {
            const target = grab.plasmoidItem.fullRepresentationItem;
            if (!target) {
                console.warn("qs-grab: no full representation to grab");
                Qt.quit();
                return;
            }
            // `qs-demo` swaps personal details for placeholders, for images
            // that end up somewhere public. A network name is enough to place
            // a home on a map.
            if (Qt.application.arguments.includes("qs-demo") && grab.plasmoidItem.network.wifiName !== "") {
                grab.plasmoidItem.network.wifiName = "Home";
            }
            const ok = target.grabToImage(result => {
                console.log("qs-grab: saved", grab.plasmoidItem.devGrabPath,
                            result.saveToFile(grab.plasmoidItem.devGrabPath));
                Qt.quit();
            });
            if (!ok) {
                console.warn("qs-grab: grabToImage refused");
                Qt.quit();
            }
        }
    }
}
