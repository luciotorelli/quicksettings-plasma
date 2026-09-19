#!/usr/bin/env bash
# Renders the widget's popup to a PNG without showing anything on screen.
#
#   tools/grab.sh out.png [extra plasmawindowed args...]
#
# Runs the package under Qt's offscreen platform, waits for the dev hook in
# main.qml (qs-grab=<path>) to write the image, then stops the process.
# QML warnings and console.log output go to <out>.log next to the image.
set -u

out=${1:?usage: tools/grab.sh out.png}
shift
out=$(realpath -m "$out")
log="${out%.png}.log"
pkg="$(cd "$(dirname "$0")/.." && pwd)/package"

rm -f "$out"
# plasmawindowed restores its last window size, which would leave a render
# taller than the content after a run that had a panel open.
sed -i '/^geometry=/d' "${XDG_CONFIG_HOME:-$HOME/.config}/plasmawindowedrc" 2>/dev/null
QT_QPA_PLATFORM=offscreen \
QT_QPA_PLATFORMTHEME=kde \
QT_QUICK_BACKEND=software \
QT_FORCE_STDERR_LOGGING=1 \
QT_LOGGING_RULES="${QT_LOGGING_RULES:-qml.debug=true;js.debug=true;kf.svg=false;kf.plasma.core=false;qt.qpa.*=false}" \
    plasmawindowed "$pkg" "qs-grab=$out" "$@" >"$log" 2>&1 &
pid=$!

for _ in $(seq 1 100); do
    [ -s "$out" ] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.2
done
sleep 0.3
kill "$pid" 2>/dev/null
wait "$pid" 2>/dev/null

if [ -s "$out" ]; then
    echo "grabbed: $out"
else
    echo "no image produced; see $log" >&2
fi
# Surface anything QML complained about.
grep -E "qml|QML|Error|error|warn|Warn|TypeError|ReferenceError|qs-grab" "$log" | grep -v "qs-grab: saved" | head -40
[ -s "$out" ]
