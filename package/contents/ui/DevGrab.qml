import QtQuick

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

    Timer {
        // Long enough for the backends, and for a panel to finish unfolding.
        interval: 2000
        running: grab.plasmoidItem !== null
        onTriggered: {
            const target = grab.plasmoidItem.fullRepresentationItem;
            if (!target) {
                console.warn("qs-grab: no full representation to grab");
                Qt.quit();
                return;
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
