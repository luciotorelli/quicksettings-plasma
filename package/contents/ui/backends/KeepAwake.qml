pragma Singleton

import QtQuick
import org.kde.plasma.workspace.dbus as DBus

// Keep Awake: one inhibition held with Plasma's power manager.
//
// On Cinnamon this took a systemd lock *and* zeroing the screen timeouts,
// because csd-power never consults logind. PowerDevil honours a single
// inhibition for both sleep and screen blanking, so there is nothing to stash
// and restore.
//
// A singleton, because the widget is often there more than once - a panel on
// each screen - and every copy runs inside the same plasmashell. With a state
// of its own in each, switching it on in one popup left the other showing it
// off, and each took out an inhibition of its own. This way there is one
// state, one inhibition, and every pill follows it.
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

    readonly property string service: "org.kde.Solid.PowerManagement.PolicyAgent"
    readonly property string path: "/org/kde/Solid/PowerManagement/PolicyAgent"
    readonly property string appName: "Quick Settings"

    // InterruptSession (1) | ChangeScreenSettings (4): no sleep, no blanking.
    readonly property int inhibitionTypes: 5

    property bool active: false
    property int cookie: 0

    property bool _started: false
    property string _marker: ""
    property string _reason: ""

    /**
     * Called by every copy of the widget as it loads; only the first call
     * does anything.
     *
     * @param {string} markerName - File name in $XDG_RUNTIME_DIR.
     * @param {string} reason - Shown by Plasma next to the inhibition. Passed
     *     in because i18n() belongs to the widget's context, not this one.
     */
    function start(markerName, reason) {
        if (_started) {
            return;
        }
        _started = true;
        _marker = '"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/' + markerName + '"';
        _reason = reason;
        shell.exec("test -e " + _marker, (stdout, exitCode) => {
            if (exitCode === 0 && !keepAwake.active) {
                keepAwake.active = true;
                keepAwake._acquire();
            }
        });
    }

    function setActive(on) {
        if (on === active || !_started) {
            return;
        }
        active = on; // echo, so the pill does not lag the click
        if (on) {
            shell.exec("touch " + _marker);
            _acquire();
        } else {
            shell.exec("rm -f " + _marker);
            const held = cookie;
            cookie = 0;
            if (held !== 0) {
                _call("ReleaseInhibition", [held], "(u)", null);
            }
        }
    }

    function _acquire() {
        _call("AddInhibition", [inhibitionTypes, appName, _reason], "(uss)", value => {
            const granted = Number(value) || 0;
            if (!keepAwake.active) {
                // Switched off again before the reply came back.
                if (granted !== 0) {
                    keepAwake._call("ReleaseInhibition", [granted], "(u)", null);
                }
                return;
            }
            keepAwake.cookie = granted;
            keepAwake.active = granted !== 0;
        });
    }

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

    Shell {
        id: shell
    }
}
