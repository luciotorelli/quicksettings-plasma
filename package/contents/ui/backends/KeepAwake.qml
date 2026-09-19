import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.dbus as DBus

// Keep Awake: one inhibition held with Plasma's power manager.
//
// On Cinnamon this took a systemd lock *and* zeroing the screen timeouts,
// because csd-power never consults logind. PowerDevil honours a single
// inhibition for both sleep and screen blanking, so there is nothing to stash
// and restore. It belongs to plasmashell's D-Bus connection, so it cannot
// outlive the session it was asked for in.
Item {
    id: keepAwake
    visible: false

    readonly property string service: "org.kde.Solid.PowerManagement.PolicyAgent"
    readonly property string path: "/org/kde/Solid/PowerManagement/PolicyAgent"
    readonly property string appName: "Quick Settings"

    // InterruptSession (1) | ChangeScreenSettings (4): no sleep, no blanking.
    readonly property int inhibitionTypes: 5

    property bool active: false
    property int cookie: 0

    function _call(member, args, signature, resolve) {
        DBus.SessionBus.asyncCall({
            service: keepAwake.service,
            path: keepAwake.path,
            iface: keepAwake.service,
            member: member,
            arguments: args,
            signature: signature,
        }, reply => {
            if (resolve) {
                // Basic types come back wrapped ({ value: 25 }), lists do not.
                const v = reply.value;
                resolve(v !== null && typeof v === "object" && "value" in v ? v.value : v);
            }
        }, error => console.warn("Quick Settings: " + member + " failed:", error && error.message));
    }

    function setActive(on) {
        if (on === active) {
            return;
        }
        active = on; // echo, so the pill does not lag the click
        if (on) {
            _call("AddInhibition", [inhibitionTypes, appName, i18n("Keep Awake is on")], "(uss)", value => {
                keepAwake.cookie = Number(value) || 0;
                Plasmoid.configuration.keepAwakeCookie = keepAwake.cookie;
                keepAwake.active = keepAwake.cookie !== 0;
            });
        } else {
            const held = cookie;
            cookie = 0;
            Plasmoid.configuration.keepAwakeCookie = 0;
            if (held !== 0) {
                _call("ReleaseInhibition", [held], "(u)", null);
            }
        }
    }

    // A widget reload loses `cookie` but not the inhibition, which stays with
    // plasmashell. The cookie is kept in the config so it can still be
    // released - but only trusted if the power manager still lists us, since
    // after a logout the old cookie means nothing.
    Component.onCompleted: {
        const saved = Plasmoid.configuration.keepAwakeCookie;
        if (!saved) {
            return;
        }
        _call("ListInhibitions", [], "", inhibitions => {
            // A list of [application, reason] pairs.
            const ours = Array.from(inhibitions || []).some(entry => entry[0] === keepAwake.appName);
            if (ours) {
                keepAwake.cookie = saved;
                keepAwake.active = true;
            } else {
                Plasmoid.configuration.keepAwakeCookie = 0;
            }
        });
    }
}
