import QtQuick
import qs
import qs.services
import qs.components

// ═══════════════════════════════════════════════════════════════════════════
//  CalendarPanel.qml - calendar that opens from the bottom-right corner when
//  the date in the bar is clicked.
//
//  The month and year on the left, the round ‹ › buttons of the island on the
//  right (or the mouse wheel) change the month; clicking the month name jumps
//  back to today. Under the weekday names a thin line, then the days. The
//  panel is only as tall as the month needs: 4, 5 or 6 weeks. Today is a white
//  circle with a dark number. Changing the month slides the days in from the
//  direction you moved.
// ═══════════════════════════════════════════════════════════════════════════
Panel {
    id: root

    open: Ui.calendarOpen
    attachBottom: true
    attachRight: true

    // 0 = this month, -1 = last month ...
    property int monthOffset: 0

    // quick slide of the days when the month changes
    property int _lastOffset: 0
    property real slide: 0
    onMonthOffsetChanged: {
        const dir = monthOffset > _lastOffset ? 1 : -1;
        _lastOffset = monthOffset;
        slide = dir * Theme.px(14);
        monthAnim.restart();
    }

    ParallelAnimation {
        id: monthAnim
        NumberAnimation {
            target: root
            property: "slide"
            to: 0
            duration: Theme.durSmall
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDecel
        }
        NumberAnimation {
            target: days
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.durSmall
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveStandard
        }
    }
    readonly property var today: Clock.date
    readonly property var shownMonth: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)

    Connections {
        target: Ui

        function onCalendarOpenChanged() {
            if (Ui.calendarOpen)
                root.monthOffset = 0;
        }
    }

    // Weeks needed by the shown month (Monday first).
    readonly property int lead: (shownMonth.getDay() + 6) % 7
    readonly property int daysInMonth: new Date(shownMonth.getFullYear(), shownMonth.getMonth() + 1, 0).getDate()
    readonly property int weeks: Math.ceil((lead + daysInMonth) / 7)

    // Day cells; days of the neighbouring months are dimmed.
    readonly property var cells: {
        const first = shownMonth;
        const list = [];
        for (let i = 0; i < weeks * 7; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - lead + i);
            list.push({
                day: d.getDate(),
                inMonth: d.getMonth() === first.getMonth(),
                today: d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate()
            });
        }
        return list;
    }

    readonly property real colW: Theme.px(46)
    readonly property real cellH: Theme.px(38)
    readonly property real gridTop: Theme.px(91)
    readonly property real gridH: weeks * cellH
    readonly property real gridW: 7 * colW
    readonly property real headerMid: Theme.px(33)          // the middle of the month / year line
    readonly property real navSize: Theme.px(32)

    // size follows the content: header + weekday row + the weeks of this month
    contentW: Theme.px(360)
    contentH: gridTop + gridH + Theme.px(5) + Theme.bar

    // mouse wheel changes the month
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.monthOffset += event.angleDelta.y > 0 ? -1 : 1
    }

    readonly property real gridX: Math.round((contentW - gridW) / 2 - Theme.frame / 2)

    // Clarity City's digits are not drawn in the middle of their own width (a 1
    // has more room on its right, a 6 on its left). Their side spacings (in
    // 1/1000 of the font size) let each number be centred by what you see, so
    // today's number sits exactly in the middle of its circle. Qt itself only
    // reports this to the nearest whole pixel, too coarse for that.
    readonly property var digitSides: ({
            "regular": {
                "left": [60, 20, 34, 30, 27, 55, 63, 22, 59, 50],
                "right": [60, 105, 57, 63, 27, 52, 50, 28, 60, 63]
            },
            "medium": {
                "left": [56, 21, 36, 29, 28, 50, 59, 24, 55, 47],
                "right": [56, 98, 55, 59, 28, 50, 47, 29, 56, 59]
            },
            "semibold": {
                "left": [52, 22, 37, 28, 29, 45, 54, 26, 51, 44],
                "right": [52, 91, 52, 53, 29, 46, 44, 30, 51, 54]
            }
        })
    function inkShift(text, weight, size) {            // weight: "regular", "medium" or "semibold"
        const t = digitSides[weight];
        const first = parseInt(text.charAt(0));
        const last = parseInt(text.charAt(text.length - 1));
        if (Theme.font !== "Clarity City" || isNaN(first) || isNaN(last))
            return 0;
        return (t.right[last] - t.left[first]) / 2 * size / 1000;
    }

    // October 2026 (the month white, the year grey), left
    Row {
        id: header
        x: root.gridX
        y: Math.round(root.headerMid - height / 2)
        spacing: Theme.px(6)

        Txt {
            text: Qt.formatDate(root.shownMonth, "MMMM")
            font.pixelSize: Theme.px(19)
            font.weight: Font.DemiBold
        }
        Txt {
            text: root.shownMonth.getFullYear()
            font.pixelSize: Theme.px(19)
            font.weight: Font.Medium
            color: Config.textDim
        }
    }
    MouseArea {
        x: header.x
        y: header.y
        width: header.width
        height: header.height
        cursorShape: Qt.PointingHandCursor
        onClicked: root.monthOffset = 0             // back to today
    }

    // ‹ › the month before / after, right (the island's round buttons: a soft
    // grey circle with a white arrow, a little bigger under the pointer)
    Row {
        x: root.gridX + root.gridW - width
        y: Math.round(root.headerMid - root.navSize / 2)
        spacing: Theme.px(8)

        RingButton {
            width: root.navSize
            icon: "chev-left"
            iconSize: Theme.px(16)
            outline: false
            offColor: Config.selected
            hoverColor: offColor             // no change under the pointer
            iconColor: Config.text
            onClicked: root.monthOffset--
        }
        RingButton {
            width: root.navSize
            icon: "chev-right"
            iconSize: Theme.px(16)
            outline: false
            offColor: Config.selected
            hoverColor: offColor             // no change under the pointer
            iconColor: Config.text
            onClicked: root.monthOffset++
        }
    }

    // Mo Tu We Th Fr Sa Su (small, grey) and a thin line under them
    Row {
        x: root.gridX
        y: Theme.px(63)

        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

            Txt {
                required property string modelData
                width: root.colW
                height: Theme.px(16)
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.pixelSize: Theme.px(12)
                font.weight: Font.Medium
                color: Config.textDim
            }
        }
    }
    Rectangle {
        x: root.gridX
        y: Theme.px(85)
        width: root.gridW
        height: 1
        color: Config.divider
    }

    // the days
    Grid {
        id: days
        x: root.gridX
        y: root.gridTop + root.slide
        columns: 7

        Repeater {
            model: root.cells

            Item {
                id: cell
                required property var modelData
                width: root.colW
                height: root.cellH

                // white circle behind today's number; it pops in when the calendar opens
                Rectangle {
                    id: marker
                    anchors.centerIn: parent
                    width: Theme.px(32)
                    height: width
                    radius: width / 2
                    color: Config.text
                    visible: cell.modelData.today

                    NumberAnimation {
                        id: markerPop
                        target: marker
                        property: "scale"
                        from: 0.5
                        to: 1
                        duration: Theme.durSmall
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveSpring
                    }
                }

                Connections {
                    target: root

                    function onOpenChanged() {
                        if (root.open && cell.modelData.today)
                            markerPop.restart();
                    }
                }

                // the number is centred by its ink (the visible digits) from top to
                // bottom, not by its line box (which has room for letters below the
                // line), so today's number sits exactly in the middle of the circle
                TextMetrics {
                    id: dayInk
                    font: dayText.font
                    text: dayText.text
                }
                Txt {
                    id: dayText
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.inkShift(text, cell.modelData.today ? "semibold" : "medium", font.pixelSize)
                    y: cell.height / 2 - (baselineOffset + dayInk.tightBoundingRect.y + dayInk.tightBoundingRect.height / 2)
                    verticalAlignment: Text.AlignTop
                    text: cell.modelData.day
                    font.pixelSize: Theme.px(15)
                    font.weight: cell.modelData.today ? Font.DemiBold : Font.Medium
                    // today: dark number on the white circle
                    color: cell.modelData.today ? Config.frame : (cell.modelData.inMonth ? Config.text : Config.textFaint)
                }
            }
        }
    }
}
