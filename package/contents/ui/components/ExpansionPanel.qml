import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// The inline panel a chevron opens: header, live list, footer action.
//
// Two things move together when it opens. The height is animated, which makes
// the whole popup grow rather than jump. The content is scaled vertically by
// the same fraction, so its bottom edge stays pinned to the clip edge: every
// row is there from the first frame and the panel unfolds as one piece,
// instead of the rows being uncovered one after another.
Item {
    id: panel

    required property Style style

    // Which panel to show; "" closes it. The content outlives the key by one
    // close animation so it does not vanish before the panel has folded shut.
    property string panelKey: ""
    property var panels: ({})           // key -> Component
    property bool snap: false           // skip the animation (switching panels)

    readonly property bool open: panelKey !== ""
    readonly property var body: loader.item
    readonly property real naturalHeight: content.implicitHeight + 24

    signal footerActivated()

    onPanelKeyChanged: {
        if (panelKey !== "") {
            loader.sourceComponent = panels[panelKey] || null;
        }
    }

    implicitHeight: open ? naturalHeight : 0
    Behavior on implicitHeight {
        enabled: !panel.snap && panel.style.panelDuration > 0
        NumberAnimation {
            // Must not overshoot: height and scale have to stay in lockstep.
            duration: panel.open ? panel.style.panelDuration : Math.round(panel.style.panelDuration * 0.75)
            easing.type: Easing.OutQuad
        }
    }

    Layout.fillWidth: true
    visible: implicitHeight > 0
    clip: true
    opacity: naturalHeight > 0 ? Math.min(1, implicitHeight / naturalHeight * 1.5) : 0

    onVisibleChanged: {
        if (!visible && !open) {
            loader.sourceComponent = null; // folded shut: let the lists go
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: panel.style.panel
    }

    ColumnLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 14
            rightMargin: 14
            topMargin: 12
        }
        spacing: 6

        transform: Scale {
            origin.y: 0
            yScale: panel.naturalHeight > 0 ? Math.min(1, panel.implicitHeight / panel.naturalHeight) : 1
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
                panel.footerActivated();
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
