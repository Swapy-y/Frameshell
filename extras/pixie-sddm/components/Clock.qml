/**
 * Pixie SDDM - Clock Component
 * Author: xCaptaiN09
 * frameshell: tabular digits (font.features), so hours and minutes line up;
 *             minutes in the same colour as the hours; theme.conf hourColor /
 *             minuteColor colour them (empty, or autoColor=true: the colour made
 *             from the accent, as before)
 */
import QtQuick

Item {
    id: clock

    property string backgroundSource: ""
    property color defaultHoursColor: "#AED68A"
    property color defaultMinutesColor: "#D4E4BC"
    property string fontFamily: "FlexRounded" // Overridden by Main.qml
    property color baseAccent: config.accentColor
    property color smartHoursColor: defaultHoursColor
    // frameshell: the minutes use exactly the hours' colour (one value, so the same hex)
    readonly property color smartMinutesColor: smartHoursColor
    // frameshell: the colours the digits get
    readonly property color hoursColor: (config.autoColor !== "true" && config.hourColor && config.hourColor.length > 0) ? config.hourColor : smartHoursColor
    readonly property color minutesColor: (config.autoColor !== "true" && config.minuteColor && config.minuteColor.length > 0) ? config.minuteColor : smartMinutesColor
    property string timeStr: ""

    function updateTime() {
        var date = new Date();
        var hours = date.getHours();
        var minutes = date.getMinutes();

        // If 24-hour is not strictly "true", convert to 12-hour format
        if (config.use24HourClock !== "true") {
            hours = hours % 12;
            if (hours === 0) hours = 12; // Midnight becomes 12
        }

        var hStr = hours < 10 ? "0" + hours : "" + hours;
        var mStr = minutes < 10 ? "0" + minutes : "" + minutes;

        clock.timeStr = hStr + mStr;
    }

    function updateColors() {
        var base = clock.baseAccent;

        if (base.hsvSaturation < 0.15) {
            clock.smartHoursColor = Qt.lighter(base, 1.3);
            return;
        }

        if (base.hsvValue < 0.5) {
            clock.smartHoursColor = Qt.hsva(base.hsvHue, 0.7, 0.9, 1.0);
        } else if (base.hsvValue > 0.8 && base.hsvSaturation < 0.2) {
            clock.smartHoursColor = Qt.hsva(base.hsvHue, 0.8, 0.7, 1.0);
        } else {
            clock.smartHoursColor = Qt.hsva(base.hsvHue, Math.min(1.0, base.hsvSaturation * 1.3), 0.95, 1.0);
        }
    }

    onBaseAccentChanged: updateColors()
    Component.onCompleted: {
        updateColors();
        updateTime();
    }

    // frameshell: tabular digits ("tnum"), the clock figures of the font: every
    // digit is 130 px wide and drawn centred in it, like the Pixel clock this
    // copies, so the hours stand exactly above the minutes. (Without it the
    // font's ordinary digits are 77 to 130 px wide, a 1 much narrower than a
    // 0, and the two rows looked shifted against each other.)
    Row {
        anchors.centerIn: parent
        spacing: 0

        Column {
            spacing: -130
            Text {
                text: clock.timeStr.charAt(0)
                color: clock.hoursColor
                font.pixelSize: 200
                font.family: clock.fontFamily
                font.weight: Font.Medium
                font.features: ({ "tnum": 1 })   // frameshell: tabular digits, see above
                width: 130
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
            Text {
                text: clock.timeStr.charAt(2)
                color: clock.minutesColor
                font.pixelSize: 200
                font.family: clock.fontFamily
                font.weight: Font.Medium
                font.features: ({ "tnum": 1 })   // frameshell: tabular digits, see above
                width: 130
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
        }

        Column {
            spacing: -130
            Text {
                text: clock.timeStr.charAt(1)
                color: clock.hoursColor
                font.pixelSize: 200
                font.family: clock.fontFamily
                font.weight: Font.Medium
                font.features: ({ "tnum": 1 })   // frameshell: tabular digits, see above
                width: 130
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
            Text {
                text: clock.timeStr.charAt(3)
                color: clock.minutesColor
                font.pixelSize: 200
                font.family: clock.fontFamily
                font.weight: Font.Medium
                font.features: ({ "tnum": 1 })   // frameshell: tabular digits, see above
                width: 130
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: updateTime()
    }
}
