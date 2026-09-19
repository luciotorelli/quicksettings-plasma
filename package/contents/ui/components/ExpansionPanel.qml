import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// The inline panel a chevron opens: header, live list, footer action.
//
// One number, `progress`, drives the whole reveal. The height follows it, and
// the content is scaled vertically by the same fraction so its bottom edge
// stays pinned to the clip edge: every row is there from the first frame and
// the panel unfolds as one piece, instead of rows being uncovered one by one.
//
// While it moves, the content is drawn through a layer - rendered once into a
// texture and that texture scaled. Scaling the live items instead makes Qt
// re-rasterise every glyph at every intermediate size, which is what made the
// reveal stutter.
Item {
    id: panel

    required property Style style

    // Which panel to show; "" closes it. The content outlives the key by one
    // close animation so it does not vanish before the panel has folded shut.
    property string panelKey: ""
    property var panels: ({})           // key -> Component
    property bool snap: false           // skip the animation (switching panels)

    // Space around the panel that appears and disappears with it. Kept in here
    // rather than in the surrounding layout's spacing, which would arrive all
    // at once the moment the panel becomes visible.
    property real gapAbove: 0
    property real gapBelow: 0

    readonly property bool open: panelKey !== ""
    readonly property var body: loader.item
    readonly property real naturalHeight: content.implicitHeight + 24
    readonly property real fullHeight: naturalHeight + gapAbove + gapBelow

    // Where the height is heading, as opposed to where the animation has got
    // to. The popup sizes its window from this, once, instead of following
    // the animation frame by frame.
    readonly property real targetHeight: open ? fullHeight : 0
    readonly property bool settled: progress === (open ? 1 : 0)

    property real progress: open ? 1 : 0
    Behavior on progress {
        enabled: !panel.snap && panel.style.panelDuration > 0
        NumberAnimation {
            // Must not overshoot: height and scale have to stay in lockstep.
            duration: panel.open ? panel.style.panelDuration : Math.round(panel.style.panelDuration * 0.75)
            easing.type: Easing.OutCubic
        }
    }

    onPanelKeyChanged: {
        if (panelKey !== "") {
            loader.sourceComponent = panels[panelKey] || null;
        }
    }

    implicitHeight: progress * fullHeight
    Layout.fillWidth: true
    visible: progress > 0
    clip: true

    onVisibleChanged: {
        if (!visible && !open) {
            loader.sourceComponent = null; // folded shut: let the lists go
        }
    }

    Rectangle {
        id: background
        anchors {
            fill: parent
            topMargin: panel.gapAbove * panel.progress
            bottomMargin: panel.gapBelow * panel.progress
        }
        radius: 18
        color: panel.style.panel
        opacity: Math.min(1, panel.progress * 1.5)
    }

    ColumnLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: background.top
            leftMargin: 14
            rightMargin: 14
            topMargin: 12 * panel.progress
        }
        spacing: 6
        opacity: Math.min(1, panel.progress * 1.5)

        layer.enabled: panel.progress > 0 && panel.progress < 1
        layer.smooth: true

        transform: Scale {
            origin.y: 0
            yScale: panel.progress
        }

        RowLayout {
            spacing: 12
            Layout.bottomMargin: 4

            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: 17
                color: panel.style.accent

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: panel.body ? panel.body.iconName : ""
                    fallback: panel.body ? panel.body.fallbackIconName : ""
                    isMask: true
                    color: panel.style.accentText
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: panel.body ? panel.body.title : ""
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            PlasmaComponents.BusyIndicator {
                implicitWidth: 22
                implicitHeight: 22
                visible: running
                running: panel.body !== null && panel.body.busy === true
            }
        }

        Loader {
            id: loader
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            implicitHeight: 1
            color: panel.style.rule
        }

        T.AbstractButton {
            id: footer
            Layout.fillWidth: true
            implicitHeight: footerLabel.implicitHeight + 8
            Accessible.name: footerLabel.text
            Accessible.role: Accessible.Button
            onClicked: {
                if (panel.body) {
                    panel.body.footerAction();
                }
            }

            contentItem: PlasmaComponents.Label {
                id: footerLabel
                leftPadding: 2
                text: panel.body ? panel.body.footerText : ""
                opacity: footer.hovered ? 1 : 0.85
                font.underline: footer.visualFocus
                verticalAlignment: Text.AlignVCenter
                textFormat: Text.PlainText
            }
        }
    }
}
