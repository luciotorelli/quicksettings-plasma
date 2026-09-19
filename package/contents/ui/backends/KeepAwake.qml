import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.dbus as DBus

// Keep Awake: one inhibition held with Plasma's power manager.
//
// On Cinnamon this took a systemd lock *and* zeroing the screen timeouts,
// because csd-power never consults logind. PowerDevil honours a single
// inhibition for both sleep and screen blanking, so there is nothing to stash
// and restore.
//
// The inhibition belongs to plasmashell's D-Bus connection, so it dies
// whenever plasmashell restarts - a crash, an update, a manual restart - and
// the pill used to come back switched off. What the user asked for is
// therefore kept separately, as a marker file in $XDG_RUNTIME_DIR, and the
// inhibition is taken out again on startup if the marker is there. That
// directory goes away on logout and reboot, so Keep Awake lasts for the login
// session, as it did on Cinnamon, and cannot be left on by accident for good.
Item {
    id: keepAwake
    visible: false

    required property var shell
    property string markerName: "quicksettings-keep-awake"

    readonly property string service: "org.kde.Solid.PowerManagement.PolicyAgent"
    readonly property string path: "/org/kde/Solid/PowerManagement/PolicyAgent"
    readonly property string appName: "Quick Settings"
    readonly property string marker: '"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/' + markerName + '"'

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

    function _acquire() {
        _call("AddInhibition", [inhibitionTypes, appName, i18n("Keep Awake is on")], "(uss)", value => {
            keepAwake.cookie = Number(value) || 0;
            Plasmoid.configuration.keepAwakeCookie = keepAwake.cookie;
            keepAwake.active = keepAwake.cookie !== 0;
        });
    }

    function _release(held) {
        if (held) {
            _call("ReleaseInhibition", [held], "(u)", null);
        }
    }

    function setActive(on) {
        if (on === active) {
            return;
        }
        active = on; // echo, so the pill does not lag the click
        if (on) {
            shell.exec("touch " + marker);
            _acquire();
        } else {
            shell.exec("rm -f " + marker);
            const held = cookie;
            cookie = 0;
            Plasmoid.configuration.keepAwakeCookie = 0;
            _release(held);
        }
    }

    // Startup. The marker says whether Keep Awake is wanted. The saved cookie
    // only matters when the widget was reloaded inside a plasmashell that is
    // still running: then the old inhibition is still there and still ours,
    // and is adopted (or, if no longer wanted, released) rather than doubled.
    Component.onCompleted: shell.exec("test -e " + marker, (stdout, exitCode) => {
        const wanted = exitCode === 0;
        const saved = Plasmoid.configuration.keepAwakeCookie;
        _call("ListInhibitions", [], "", inhibitions => {
            // A list of [application, reason] pairs.
            const alive = saved !== 0
                && Array.from(inhibitions || []).some(entry => entry[0] === keepAwake.appName);
            if (wanted && alive) {
                keepAwake.cookie = saved;
                keepAwake.active = true;
            } else if (wanted) {
                keepAwake.active = true;
                keepAwake._acquire();
            } else {
                Plasmoid.configuration.keepAwakeCookie = 0;
                if (alive) {
                    keepAwake._release(saved);
                }
            }
        });
    })
}
