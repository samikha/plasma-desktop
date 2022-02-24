/*
    SPDX-FileCopyrightText: 2013 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2022 Niccolò Venerandi <niccolo@venerandi.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.5
import QtQuick.Layouts 1.0

import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kquickcontrolsaddons 2.0

MouseArea {
    id: configurationArea

    z: 1000

    anchors.fill: currentLayout

    hoverEnabled: true

    property Item currentApplet
    property int lastX
    property int lastY

    readonly property int spacerHandleSize: PlasmaCore.Units.smallSpacing
    property bool isHorizontal: plasmoid.formFactor === PlasmaCore.Types.Horizontal //TODO read this from main.qml

    //onHeightChanged: tooltip.visible = false;
    //onWidthChanged: tooltip.visible = false; //TODO why?

    onPositionChanged: {
        if (pressed) {

            // If the object has been dragged outside of the panel and there's
            // a different containment there, we remove it from the panel
            // containment and add it to the new one.
            var padding = PlasmaCore.Units.gridUnit * 5;
            if (currentApplet && (mouse.x < -padding || mouse.y < -padding ||
                mouse.x > width + padding || mouse.y > height + padding)) {
                var newCont = plasmoid.containmentAt(mouse.x, mouse.y);

                if (newCont && newCont !== plasmoid) {
                    var newPos = newCont.mapFromApplet(plasmoid, mouse.x, mouse.y);
                    var applet = currentApplet.applet;
                    currentApplet.destroy();
                    applet.anchors.fill = undefined
                    newCont.addApplet(applet, newPos.x, newPos.y);
                    return;
                }
            }
            if (plasmoid.formFactor === PlasmaCore.Types.Vertical) {
                currentApplet.y += (mouse.y - lastY);
            } else {
                currentApplet.x += (mouse.x - lastX);
            }

            var item = currentLayout.childAt(mouse.x, mouse.y);

            if (item && item.applet !== placeHolder) {
                var posInItem = mapToItem(item, mouse.x, mouse.y);
                if ((!isHorizontal && posInItem.y < item.height/3) ||
                    (isHorizontal && posInItem.x < item.width/3)) {
                    root.layoutManager.move(placeHolder.parent.index, item.index)
                } else if ((!isHorizontal && posInItem.y > 2*item.height/3) ||
                          (isHorizontal && posInItem.x > 2*item.width/3)) {
                    root.layoutManager.move(placeHolder.parent.index, item.index+1)
                }
            }

        } else {
            var item = currentLayout.childAt(mouse.x, mouse.y);
            if (root.dragOverlay && item) {
                root.dragOverlay.currentApplet = item;
            }/* else {
                root.dragOverlay.currentApplet = null;
            }*/
        }

        if (root.dragOverlay.currentApplet) {
            hideTimer.stop();
            tooltip.raise();
        }
        lastX = mouse.x;
        lastY = mouse.y;
    }

    onEntered: hideTimer.stop();

    onExited: hideTimer.start()

    onCurrentAppletChanged: {
        if (!currentApplet || !root.dragOverlay.currentApplet) {
            hideTimer.start();
            return;
        }
    }

    onPressed: {
        // Need to set currentApplet here too, to make touch selection + drag
        // with with a touchscreen, because there are no entered events in that
        // case
        let item = currentLayout.childAt(mouse.x, mouse.y);
        if (!item) {return}
        tooltip.raise();
        hideTimer.stop();

        // We set the current applet being dragged as a property of placeHolder
        // to be able to read its properties from the LayoutManager
        appletsModel.insert(item.index, {applet: placeHolder});
        placeHolder.parent.inThickArea = item.inThickArea
        currentApplet = appletContainerComponent.createObject(root, {applet: item.applet, x: item.x, y: item.y, z: 900,
                                                                     width: item.width, height: item.height, index: -1})
        placeHolder.parent.dragging = currentApplet
        appletsModel.remove(item.index)
        root.dragAndDropping = true
    }

    onReleased: finishDragOperation()

    onCanceled: finishDragOperation()

    function finishDragOperation() {
        root.dragAndDropping = false
        if (!currentApplet) {
            return;
        }
        appletsModel.set(placeHolder.parent.index, {applet: currentApplet.applet})
        let newCurrentApplet = currentApplet.applet.parent
        newCurrentApplet.animateFrom(currentApplet.x, currentApplet.y)
        newCurrentApplet.dragging = null
        placeHolder.parent = configurationArea;
        currentApplet.destroy()
        root.layoutManager.save()
    }

    Item {
        id: placeHolder
        property Item dragging
        property bool busy: false
        Layout.preferredWidth: currentApplet ? currentApplet.Layout.preferredWidth : 0
        Layout.preferredHeight: currentApplet ? currentApplet.Layout.preferredHeight : 0
        Layout.maximumWidth: currentApplet ? currentApplet.Layout.maximumWidth : 0
        Layout.maximumHeight: currentApplet ? currentApplet.Layout.maximumHeight : 0
        Layout.minimumWidth: currentApplet ? currentApplet.Layout.minimumWidth : 0
        Layout.minimumHeight: currentApplet ? currentApplet.Layout.minimumHeight : 0
        visible: configurationArea.containsMouse
        Layout.fillWidth: currentApplet ? currentApplet.Layout.fillWidth : false
        Layout.fillHeight: currentApplet ? currentApplet.Layout.fillHeight : false
    }

    Timer {
        id: hideTimer
        interval: PlasmaCore.Units.longDuration * 5
        onTriggered: currentApplet = null
    }

    Rectangle {
        id: handle
        x: currentApplet ? currentApplet.x : 0
        y: currentApplet ? currentApplet.y : 0
        width: currentApplet ? currentApplet.width : 0
        height: currentApplet ? currentApplet.height : 0
        visible: configurationArea.containsMouse
        color: PlasmaCore.Theme.backgroundColor
        radius: 3
        opacity: currentApplet ? 0.5 : 0
        PlasmaCore.IconItem {
            source: "transform-move"
            width: Math.min(parent.width, parent.height)
            height: width
            anchors.centerIn: parent
        }
        Behavior on x {
            enabled: !configurationArea.pressed
            NumberAnimation {
                duration: PlasmaCore.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }
        Behavior on y {
            enabled: !configurationArea.pressed
            NumberAnimation {
                duration: PlasmaCore.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }
        Behavior on width {
            enabled: !configurationArea.pressed
            NumberAnimation {
                duration: PlasmaCore.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }
        Behavior on height {
            enabled: !configurationArea.pressed
            NumberAnimation {
                duration: PlasmaCore.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: PlasmaCore.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }
    }
    PlasmaCore.Dialog {
        id: tooltip
        visible: currentApplet && !root.dragAndDropping
        visualParent: currentApplet

        type: PlasmaCore.Dialog.Dock
        flags: Qt.WindowStaysOnTopHint|Qt.WindowDoesNotAcceptFocus|Qt.BypassWindowManagerHint
        location: plasmoid.location

        onVisualParentChanged: {
            if (visualParent) {
                currentApplet.applet.prepareContextualActions();
                alternativesButton.visible = currentApplet.applet.action("alternatives") && currentApplet.applet.action("alternatives").enabled;
                configureButton.visible = currentApplet.applet.action("configure") && currentApplet.applet.action("configure").enabled;
                label.text = currentApplet.applet.title;
            }
        }

        mainItem: MouseArea {
            enabled: currentApplet && !root.dragAndDropping
            width: handleButtons.width
            height: handleButtons.height
            hoverEnabled: true
            onEntered: hideTimer.stop();
            onExited:  hideTimer.restart();

            ColumnLayout {
                id: handleButtons
                spacing: PlasmaCore.Units.smallSpacing

                PlasmaExtras.PlasmoidHeading {
                    leftPadding: PlasmaCore.Units.smallSpacing * 2
                    rightPadding: PlasmaCore.Units.smallSpacing * 2

                    contentItem: PlasmaExtras.Heading {
                        id: label
                        level: 3
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                PlasmaComponents.ToolButton {
                    Layout.fillWidth: true
                    // we want destructive actions to be far from the initial
                    // cursor position, so show this on the top unless it's on
                    // a top panel
                    visible: tooltip.location !== PlasmaCore.Types.TopEdge
                             && currentApplet
                             && currentApplet.applet.action("remove")
                             && currentApplet.applet.action("remove").enabled
                    iconSource: "delete"
                    text: i18n("Remove")
                    onClicked: {
                        currentApplet.applet.action("remove").trigger();
                        currentApplet = null
                    }
                }
                PlasmaComponents.ToolButton {
                    id: configureButton
                    Layout.fillWidth: true
                    iconSource: "configure"
                    text: i18n("Configure…")
                    onClicked: {
                        currentApplet.applet.action("configure").trigger()
                        currentApplet = null
                    }
                }
                PlasmaComponents.ToolButton {
                    id: alternativesButton
                    Layout.fillWidth: true
                    iconSource: "widget-alternatives"
                    text: i18n("Show Alternatives…")
                    onClicked: {
                        currentApplet.applet.action("alternatives").trigger()
                        currentApplet = null
                    }
                }
                PlasmaComponents.ToolButton {
                    Layout.fillWidth: true
                    // we want destructive actions to be far from the initial
                    // cursor position, so show this on the bottom for top panels
                    visible: tooltip.location === PlasmaCore.Types.TopEdge
                             && currentApplet
                             && currentApplet.applet.action("remove")
                             && currentApplet.applet.action("remove").enabled
                    iconSource: "delete"
                    text: i18n("Remove")
                    onClicked: {
                        currentApplet.applet.action("remove").trigger()
                        currentApplet = null
                    }
                }
            }
        }
    }
}
