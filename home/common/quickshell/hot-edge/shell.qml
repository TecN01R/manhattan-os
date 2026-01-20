import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: edgeWindow
        required property var modelData

        screen: modelData

        WlrLayershell.namespace: "hot-edge-bottom"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: -1

        anchors.left: true
        anchors.right: true
        anchors.bottom: true

        height: 2
        color: "transparent"

        Timer {
            id: cooldown
            interval: 600
            repeat: false
        }

        HoverHandler {
            onHoveredChanged: {
                if (!hovered || cooldown.running) {
                    return;
                }
                Quickshell.execDetached(["niri", "msg", "action", "toggle-overview"]);
                cooldown.restart();
            }
        }
    }
}
