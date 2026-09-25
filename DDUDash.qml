/*****************************************************************************
**  GTDash.qml  —  Bosch Motorsport DDU 10 Black & Blue Edition (SINGLE-FILE build)
**
**  Pixel-perfect Bosch Motorsport DDU 10 digital dash cluster with exact
**  black & electric blue color styling, 9000 RPM tachometer arc with cyan/yellow/red
**  staging (Yellow @ 8000 RPM, Red @ 8500 RPM, All LEDs lit @ 8750 RPM max),
**  tight left TEMPS section (IAT, Coolant, AFR) with numbers tucked close to bars,
**  right PEAKS section (Peak RPM, Max Speed, Peak IAT, Peak Lambda/AFR) spaced
**  well away from the rev sweep, vertically aligned Fuel & Speed pods.
**
**  Pure QtQuick 2.7 core (no QtGraphicalEffects / Controls) for full IC7 (Qt 5.12)
**  hardware compatibility. Single background Canvas for static chrome; declarative
**  GPU scene-graph nodes for all dynamic animated readouts.
**
**     Up                  open the settings menu
**     Left / Right        move between settings
**     Up / Down           change the selected value (hold to ramp, 250 RPM steps)
**     Down (Hold)         reset peak telemetry memory
**     EXIT row + Up       save to config path & close
*****************************************************************************/
import QtQuick 2.7
import FileIO 1.0

Item {
    id: root
    width: 800; height: 480

    // ---- data interface (real rpmtest field names, dot-notation) ----------
    property var d: (typeof rpmtest !== 'undefined') ? rpmtest : null
    property real rpm:       d ? d.rpmdata          : 0
    property real speed:     d ? d.speeddata        : 0      // km/h
    property real peakRpm:   0      // session high-water marks
    property real peakRpmMin:  1e9   // session low-water mark
    property real peakSpeed: 0      // km/h canonical -> reset on power cycle / hold-down
    property real peakSpeedMin: 1e9  // session min speed
    property real peakOilTemp:     -1e9   // session max, C canonical (IAT)
    property real peakOilTempMin:   1e9   // session min, C canonical (IAT)
    property real peakCoolant:     -1e9   // session max, C canonical
    property real peakOilPressMax: -1e9   // session max, PSI canonical
    property real peakOilPressMin:  1e9   // session min, PSI canonical
    property real peakAfrMax:      -1e9   // session max, AFR canonical
    property real peakAfrMin:       1e9   // session min, AFR canonical

    onSpeedChanged:     { if (speed > peakSpeed)   peakSpeed   = speed; if (speed < peakSpeedMin && speed > 0) peakSpeedMin = speed; }
    onOiltempChanged:   { if (oiltemp > peakOilTemp) peakOilTemp = oiltemp; if (oiltemp < peakOilTempMin) peakOilTempMin = oiltemp; }
    onWatertempChanged: if (watertemp > peakCoolant) peakCoolant = watertemp
    onAfrChanged:       { if (afr > peakAfrMax) peakAfrMax = afr;
                          if (afr < peakAfrMin) peakAfrMin = afr; }

    function resetPeaks() {
        peakRpm         = rpm;
        peakRpmMin      = rpm;
        peakSpeed       = speed;
        peakSpeedMin    = speed;
        peakOilTemp     = oiltemp;
        peakOilTempMin  = oiltemp;
        peakCoolant     = watertemp;
        peakOilPressMax = oilpress;
        peakOilPressMin = oilpress;
        peakAfrMax      = afr;
        peakAfrMin      = afr;
    }

    property real watertemp: d ? d.watertempdata    : 0      // °C (native)
    property real fuel:      d ? d.fueldata         : 0      // % (0..100)
    property real odometer:  d ? (d.odometer0data    / 10) : 0   // tenths of km (matches GTDash)
    property int  tripmeter: d ? (d.tripmileage0data / 10) : 0   // tenths of km (matches GTDash)
    property int  gearpos:   d ? d.geardata         : 0      // 0=N, 1..8=gears, 9=P, 10=R
    property int  inputs:    d ? d.inputsdata       : 0      // bitmask of telltales / buttons
    // turn-signal telltales mirror the flasher-relay bits (0x40 left / 0x80 right)
    // directly (no dash-side blink timer) so the arrows light/darken in sync with
    // the bulb -- refreshed each 40 ms by the input poll (evalEdges).
    property bool tLeftActive:  false
    property bool tRightActive: false

    property real oiltemp:   d ? d.oiltempdata      : 0      // °C (oil temp)
    property real oilpress:  d ? (d.oilpressuredata * 14.5038) : 0  // native BAR -> PSI
    property real oilPressShown: 0
    Behavior on oilPressShown { SmoothedAnimation { velocity: 60 } }
    onOilpressChanged: { oilPressShown = oilpress;
                         if (oilpress > peakOilPressMax) peakOilPressMax = oilpress;
                         if (oilpress < peakOilPressMin) peakOilPressMin = oilpress; }

    property real afr:       d ? (d.o2data * 14.7)  : 0      // native lambda -> AFR
    property real battery:   d ? d.batteryvoltagedata : 0    // volts
    property real batteryShown: 0

    // =======================================================================
    //  SETTABLE CONFIG (37 variables, persisted to disk)
    // =======================================================================
    property int  rpmredline: 8750     // SHIFT RPM (calibrated 8750 max limit)
    property int  rpmmax:     9000     // RPM LIMIT (full scale 9000 RPM, integer 250 steps)
    property int  rpmDamp:    3        // RPM DAMPING (1..10)

    // Bosch DDU 10 Black & Blue default palette (0 / 180 / 255)
    property int  red:   0
    property int  green: 180
    property int  blue:  255

    property int  speedunits: 1        // 0 = km/h, 1 = mph
    property int  distunits:  1        // 0 = km,   1 = miles
    property int  tempunits:  0        // 0 = °C, 1 = °F

    property real coolantHigh:   110   // °C
    property real coolantLow:    60    // °C
    property int  fuelHigh:      90
    property int  fuelLow:       15    // %
    property int  fuelDamp:      3
    property real oilTempHigh:   130   // °C
    property real oilTempLow:    40    // °C
    property int  oilTempUnits:  0     // 0 = °C, 1 = °F, 2 = OFF
    property real oilPressHigh:  90    // PSI
    property real oilPressLow:   15    // PSI
    property int  oilPressUnits: 0     // 0 = PSI, 1 = BAR, 2 = OFF
    property real batteryHigh:   14.8
    property real batteryLow:    11.8
    property real afrHigh:       1.02   // Lambda limits
    property real afrLow:        0.82
    property int  nightlight:    100
    property int  afrSource:     1     // 0 = AFR, 1 = LAMBDA, 2 = OFF

    readonly property real afrShown: afrSource === 1 ? afr / 14.7 : afr

    readonly property bool showOilTemp:  oilTempUnits  <= 1
    readonly property bool showOilPress: oilPressUnits !== 2
    readonly property bool showCoolant:  tempunits     !== 2
    readonly property bool showAfr:      afrSource     !== 2
    readonly property bool showPeak:     true
    property bool showPeakGauge:     true
    property int  peakGaugePosition: 2
    property bool peakShowRpm:      true
    property bool peakShowSpeed:    true
    property bool peakShowAfr:      true
    property bool peakShowOilTemp:  true
    property bool peakShowOilPress: true
    property bool peakShowCoolant:  true

    // Units conversion helpers
    readonly property real distFactor: distunits === 0 ? 1.0 : 0.621371
    readonly property string distUnit: distunits === 0 ? " KM" : " MI"
    readonly property real speedFactor: speedunits === 0 ? 1.0 : 0.621371
    readonly property string speedUnit: speedunits === 0 ? "kph" : "mph"

    function fmtTemp(cVal, u) {
        if (cVal <= -1e8) return "--";
        var v = (u === 1) ? (cVal * 9/5 + 32) : cVal;
        return Math.round(v) + (u === 1 ? "\u00B0F" : "\u00B0C");
    }
    function fmtPress(psiVal, u) {
        if (psiVal <= -1e8) return "--";
        var v = (u === 1) ? (psiVal / 14.5038) : psiVal;
        return (u === 1) ? v.toFixed(1) + " BAR" : Math.round(v) + " PSI";
    }

    // Spring damping & needle response
    readonly property real springVal: 3.5 + (11 - Math.max(1, Math.min(10, root.rpmDamp))) * 2.2
    readonly property real springDamp: 0.30 + springVal * 0.025
    property real rpmDisplay: 0
    Behavior on rpmDisplay { SpringAnimation { spring: root.springVal; damping: root.springDamp; epsilon: 1 } }
    onRpmChanged: { rpmDisplay = rpm; if (rpm > peakRpm) peakRpm = rpm; if (rpm > 0 && rpm < peakRpmMin) peakRpmMin = rpm; }

    // Power-on self-test sweep
    property bool  selfTest: true
    property real  sweepRpm: 0
    property real  settle:   0
    readonly property real rpmShown: selfTest ? (sweepRpm * (1 - settle) + rpmDisplay * settle) : rpmDisplay
    readonly property real sweepFrac: Math.max(0, Math.min(1, sweepRpm / Math.max(1, rpmmax)))

    SequentialAnimation {
        id: bootSweep; running: false
        NumberAnimation { target: root; property: "sweepRpm"; from: 0; to: root.rpmmax; duration: 850; easing.type: Easing.OutCubic }
        PauseAnimation  { duration: 200 }
        NumberAnimation { target: root; property: "settle";   from: 0; to: 1;            duration: 700; easing.type: Easing.InOutCubic }
        ScriptAction    { script: root.selfTest = false }
    }

    // Fuel smoothing
    readonly property real fuelVel: Math.max(8.0, 75.0 - (fuelDamp - 1) * 8.0)
    property real fuelDisplay: 0
    Behavior on fuelDisplay { SmoothedAnimation { velocity: root.fuelVel } }
    onFuelChanged: fuelDisplay = fuel
    readonly property real fuelLevel: (fuelDamp <= 0) ? fuel : fuelDisplay
    readonly property real fuelBarFrac: selfTest ? (sweepFrac * (1 - settle) + (fuelLevel / 100) * settle) : fuelLevel / 100

    property bool overrev: rpmShown >= 8500
    property bool engineOff: !selfTest && Math.round(rpmShown) < 1
    property bool placementSwap: false
    property bool hideTachNums: false
    property bool hideShiftLights: false
    property int  speedShown: (speedunits === 0) ? Math.round(speed) : Math.round(speed * 0.621371)

    property string gearLabel: {
        switch (gearpos) {
            case 0: return "N";
            case 9: return "P";
            case 10: return "R";
            default: return (gearpos >= 1 && gearpos <= 8) ? String(gearpos) : "N";
        }
    }

    // Bundled font
    FontLoader { id: uiFontR; source: "assets/DejaVuSans.ttf"
        onStatusChanged: if (status === FontLoader.Ready && typeof bg !== 'undefined') bg.requestPaint() }
    FontLoader { id: uiFontB; source: "assets/DejaVuSans-Bold.ttf" }
    // Canvas ctx.font needs the family QUOTED ("DejaVu Sans"); QML Text.font.family needs it UNQUOTED.
    readonly property string ff:       (uiFontR.status === FontLoader.Ready && uiFontR.name !== "") ? ('"' + uiFontR.name + '"') : "sans-serif"
    readonly property string menuFont: (uiFontR.status === FontLoader.Ready && uiFontR.name !== "") ? uiFontR.name : "sans-serif"

    // Debounce & Blink timers
    property bool blinkOn: true
    Timer { interval: 400; repeat: true; running: true; onTriggered: root.blinkOn = !root.blinkOn }
    Timer {
        interval: 350; repeat: true; running: true
        onTriggered: {
            if (root.batteryShown === 0 || Math.abs(root.battery - root.batteryShown) >= 0.08)
                root.batteryShown = root.battery;
        }
    }

    // =======================================================================
    //  STATIC BACKGROUND CANVAS (Painted once on boot & setting changes)
    // =======================================================================
    Canvas {
        id: bg
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            // 1. Deep Matte Pitch Black Screen
            ctx.fillStyle = "#000000";
            ctx.fillRect(0, 0, width, height);

            var cx = 400, cy = 215;

            // 2. Symmetrical Angular Cyber Framing Brackets
            // Left Cyber Bracket (over TEMP): x 35 -> 210 -> (245, 138)
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = "#0d3a63";
            ctx.beginPath();
            ctx.moveTo(35, 104);
            ctx.lineTo(210, 104);
            ctx.lineTo(245, 138);
            ctx.stroke();

            // Left glowing cyan accent pip
            ctx.strokeStyle = "#1eb8ff";
            ctx.lineWidth = 2.0;
            ctx.beginPath();
            ctx.moveTo(35, 104);
            ctx.lineTo(90, 104);
            ctx.stroke();

            // Right Cyber Bracket (over PEAKS): (555, 138) -> 590 -> 765
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = "#0d3a63";
            ctx.beginPath();
            ctx.moveTo(555, 138);
            ctx.lineTo(590, 104);
            ctx.lineTo(765, 104);
            ctx.stroke();

            // Right glowing cyan accent pip
            ctx.strokeStyle = "#1eb8ff";
            ctx.lineWidth = 2.0;
            ctx.beginPath();
            ctx.moveTo(710, 104);
            ctx.lineTo(765, 104);
            ctx.stroke();

            // Symmetrical Horizontal Dividers (y: 278)
            ctx.lineWidth = 1.0;
            ctx.strokeStyle = "#091e32";
            ctx.beginPath(); ctx.moveTo(35, 278); ctx.lineTo(225, 278); ctx.stroke();
            ctx.beginPath(); ctx.moveTo(575, 278); ctx.lineTo(765, 278); ctx.stroke();

            // 3. Central Tachometer Baseline Circular Track (9000 RPM Scale)
            var rIn = 108, rOut = 134;
            var aStart = 140 * Math.PI / 180;
            var aEnd   = 400 * Math.PI / 180;

            // Dark Baseline Groove
            ctx.beginPath();
            ctx.arc(cx, cy, (rIn + rOut)/2, aStart, aEnd, false);
            ctx.lineWidth = rOut - rIn;
            ctx.strokeStyle = "#071626";
            ctx.stroke();

            // Inner and Outer Track Borders
            ctx.lineWidth = 1.2;
            ctx.strokeStyle = "#0f3659";
            ctx.beginPath(); ctx.arc(cx, cy, rIn, aStart, aEnd, false); ctx.stroke();
            ctx.beginPath(); ctx.arc(cx, cy, rOut, aStart, aEnd, false); ctx.stroke();

            // Full Scale Numbers 0..9 (9000 RPM) & Radial Tick Marks
            var maxK = 9;
            ctx.font = "bold 13px " + root.ff;
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";

            for (var k = 0; k <= maxK; k++) {
                var frac = k / maxK;
                var deg = 140 + frac * 260;
                var rad = deg * Math.PI / 180;
                var cos = Math.cos(rad);
                var sin = Math.sin(rad);

                var tickRpm = k * 1000;
                var isRed = tickRpm >= 8500;
                var isYellow = tickRpm >= 8000 && tickRpm < 8500;

                // Major tick line
                ctx.lineWidth = 1.8;
                ctx.strokeStyle = isRed ? "#ff3344" : (isYellow ? "#ffcc00" : "#ffffff");
                ctx.beginPath();
                ctx.moveTo(cx + (rOut + 2) * cos, cy + (rOut + 2) * sin);
                ctx.lineTo(cx + (rOut + 11) * cos, cy + (rOut + 11) * sin);
                ctx.stroke();

                // Scale numbers (0, 1, 2, 3, 4, 5, 6, 7, 8, 9)
                if (!root.hideTachNums) {
                    var tx = cx + (rOut + 22) * cos;
                    var ty = cy + (rOut + 22) * sin;
                    ctx.fillStyle = isRed ? "#ff5555" : (isYellow ? "#ffdd44" : "#e1f0ff");
                    ctx.fillText(String(k), tx, ty);
                }

                // Minor 500 RPM ticks
                if (k < maxK) {
                    var mDeg = 140 + (frac + 0.5/maxK) * 260;
                    var mRad = mDeg * Math.PI / 180;
                    var mRpm = (k + 0.5) * 1000;
                    ctx.lineWidth = 1.0;
                    ctx.strokeStyle = (mRpm >= 8500) ? "#cc2233" : ((mRpm >= 8000) ? "#c8a200" : "#406585");
                    ctx.beginPath();
                    ctx.moveTo(cx + (rOut + 2) * Math.cos(mRad), cy + (rOut + 2) * Math.sin(mRad));
                    ctx.lineTo(cx + (rOut + 7) * Math.cos(mRad), cy + (rOut + 7) * Math.sin(mRad));
                    ctx.stroke();
                }
            }

            // 4. Lower Gear Conical Runway
            var rwTopL = 352, rwTopR = 448, rwTopY = 260;
            var rwBotL = 312, rwBotR = 488, rwBotY = 416;

            ctx.beginPath();
            ctx.moveTo(rwTopL, rwTopY);
            ctx.lineTo(rwBotL, rwBotY);
            ctx.lineTo(rwBotR, rwBotY);
            ctx.lineTo(rwTopR, rwTopY);
            ctx.closePath();
            var rwGrad = ctx.createLinearGradient(cx, rwTopY, cx, rwBotY);
            rwGrad.addColorStop(0, "#05182c");
            rwGrad.addColorStop(1, "#01060e");
            ctx.fillStyle = rwGrad;
            ctx.fill();

            // Left & Right Glowing Cyan Runway Rails
            ctx.lineWidth = 2.0;
            ctx.strokeStyle = "#1eb8ff";
            ctx.beginPath(); ctx.moveTo(rwTopL, rwTopY); ctx.lineTo(rwBotL, rwBotY); ctx.stroke();
            ctx.beginPath(); ctx.moveTo(rwTopR, rwTopY); ctx.lineTo(rwBotR, rwBotY); ctx.stroke();

            // Bottom Runway Base Bar
            ctx.lineWidth = 1.2;
            ctx.strokeStyle = "#0e3557";
            ctx.beginPath(); ctx.moveTo(rwBotL, rwBotY); ctx.lineTo(rwBotR, rwBotY); ctx.stroke();

            // 5. Center RPM Hub Disc
            ctx.beginPath();
            ctx.arc(cx, cy, 68, 0, 2 * Math.PI, false);
            ctx.fillStyle = "#040b15";
            ctx.fill();
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = "#0e3455";
            ctx.stroke();

            // Hub top cyan arc accent
            ctx.beginPath();
            ctx.arc(cx, cy, 68, 200 * Math.PI / 180, 340 * Math.PI / 180, false);
            ctx.lineWidth = 2.0;
            ctx.strokeStyle = "#1eb8ff";
            ctx.stroke();

            // 6. Bosch Motorsport Lower Left Branding Tag
            ctx.font = "bold 11px " + root.ff;
            ctx.fillStyle = "#4a6c8c";
            ctx.textAlign = "left";
            ctx.fillText("Motorsport", 24, 468);
        }
    }

    // =======================================================================
    //  TOP BEZEL LED SHIFT LIGHT BAR (10 LEDs: 6 Green, 2 Yellow, 2 Red)
    //  Staged: Green < 8000, Yellow @ 8000..8500, Red @ 8500..8750 (All ON @ 8750)
    // =======================================================================
    Item {
        id: topShiftLeds
        anchors.top: parent.top; anchors.topMargin: 36   // dropped ~0.5cm to clear the dash cowl
        anchors.horizontalCenter: parent.horizontalCenter
        width: 320; height: 16
        visible: !root.hideShiftLights

        // Sequential proportional shift bar:
        // first green segment starts at 50% of the configured redline,
        // then the bar fills green -> yellow -> red as RPM rises.
        Row {
            anchors.centerIn: parent
            spacing: 8
            Repeater {
                model: 10
                Rectangle {
                    width: 20; height: 9; radius: 4.5

                    readonly property real startFrac: 0.50
                    readonly property real spanFrac: 0.50
                    readonly property real segmentFrac: (index + 1) / 10.0
                    readonly property real rpmThreshold:
                        root.rpmredline * (startFrac + spanFrac * segmentFrac)

                    readonly property bool lit:
                        root.selfTest || (root.rpmShown >= rpmThreshold)

                    readonly property color segmentColor:
                        index < 6 ? "#00e640"
                        : index < 8 ? "#ffcc00"
                        : "#ff2233"

                    color: lit ? segmentColor : "#071622"
                    border.color: lit ? "#ffffff" : "#0d283c"
                    border.width: 1
                    opacity: lit ? 1.0 : 0.4

                    Rectangle {
                        visible: parent.lit
                        anchors.centerIn: parent
                        width: 24; height: 13; radius: 6
                        color: parent.segmentColor
                        opacity: 0.35
                    }
                }
            }
        }
    }

    // Side Warning Pills (3 Left, 3 Right)
    Item {
        id: sideLeds
        anchors.fill: parent
        // Left 3
        Repeater {
            model: 3
            Rectangle {
                x: 14; y: 142 + index * 32
                width: 16; height: 7; radius: 3.5
                color: "#00b4ff"
                border.color: "#4de2ff"
                border.width: 1
                opacity: 0.9
            }
        }
        // Right 3
        Repeater {
            model: 3
            Rectangle {
                x: 770; y: 142 + index * 32
                width: 16; height: 7; radius: 3.5
                color: "#00b4ff"
                border.color: "#4de2ff"
                border.width: 1
                opacity: 0.9
            }
        }
    }

    // =======================================================================
    //  TACHOMETER ACTIVE SWEEP LAYER (0..9000 RPM, Cyan/Yellow/Red Staging)
    // =======================================================================
    Item {
        id: tachSweep
        anchors.fill: parent
        readonly property real activeMaxRpm: 9000
        property int tickCount: Math.floor(activeMaxRpm / 80) + 1

        Repeater {
            model: tachSweep.tickCount
            delegate: Item {
                readonly property int    v:        index * 80
                readonly property bool   isRed:    v >= 8500
                readonly property bool   isYellow: v >= 8000 && v < 8500
                readonly property bool   lit:      v <= root.rpmShown + 20
                readonly property real   angleDeg: 140 + (v / tachSweep.activeMaxRpm) * 260
                readonly property real   aRad:     angleDeg * Math.PI / 180
                readonly property real   ri:       109
                readonly property real   ro:       133
                readonly property real   rmid:     (ri + ro) / 2
                readonly property real   cxg:      400 + rmid * Math.cos(aRad)
                readonly property real   cyg:      215 + rmid * Math.sin(aRad)
                readonly property color  litCol:   isRed ? "#ff2a3b" : (isYellow ? "#ffcc00" : "#1eb8ff")

                // Glow Band behind active spokes
                Rectangle {
                    width: 12; height: 26; radius: 5
                    antialiasing: true
                    color: parent.litCol
                    opacity: parent.lit ? (parent.isRed ? 0.32 : (parent.isYellow ? 0.28 : 0.22)) : 0
                    x: parent.cxg - width / 2; y: parent.cyg - height / 2
                    transformOrigin: Item.Center
                    rotation: parent.angleDeg + 90
                }
                // Solid Active Arc Spoke
                Rectangle {
                    width: 3.5; height: 24; radius: 1.5
                    antialiasing: true
                    color: parent.litCol
                    opacity: parent.lit ? 1.0 : 0
                    x: parent.cxg - width / 2; y: parent.cyg - height / 2
                    transformOrigin: Item.Center
                    rotation: parent.angleDeg + 90
                }
            }
        }

        // Leading Edge White Needle Ray
        Item {
            id: tachNeedle
            property real curAngle: 140 + (root.rpmShown / tachSweep.activeMaxRpm) * 260
            property real nRad: curAngle * Math.PI / 180
            x: 400 + 126 * Math.cos(nRad)
            y: 215 + 126 * Math.sin(nRad)
            visible: !root.engineOff

            Rectangle {
                anchors.centerIn: parent
                width: 4.5; height: 34; radius: 2
                color: root.overrev ? "#ff4444" : (root.rpmShown >= 8000 ? "#ffdd44" : "#ffffff")
                transformOrigin: Item.Center
                rotation: tachNeedle.curAngle + 90
                Rectangle {
                    anchors.centerIn: parent
                    width: 10; height: 38; radius: 4
                    color: root.overrev ? "#ff4444" : (root.rpmShown >= 8000 ? "#ffcc00" : "#1eb8ff")
                    opacity: 0.45
                }
            }
        }
    }

    // =======================================================================
    //  CENTER HUB (RPM Digit Readout + GEAR in Lower Runway)
    // =======================================================================
    Item {
        id: centerHub
        anchors.fill: parent

        // Central Big White RPM
        Text {
            id: rpmText
            anchors.horizontalCenter: parent.horizontalCenter
            y: 184
            text: root.engineOff ? "----" : String(Math.round(root.rpmShown / 10) * 10)
            color: root.engineOff ? "#3d546e" : (root.overrev ? (root.blinkOn ? "#ff4040" : "#ffffff") : (root.rpmShown >= 8000 ? "#ffea4a" : "#ffffff"))
            font.family: root.menuFont; font.bold: true; font.pixelSize: 38
            font.letterSpacing: 1
        }
        Text {
            anchors.top: rpmText.bottom; anchors.topMargin: -4
            anchors.horizontalCenter: parent.horizontalCenter
            text: "rpm"
            color: root.engineOff ? "#3d546e" : "#4fc3f7"
            font.family: root.menuFont; font.bold: true; font.pixelSize: 13
        }

        // Giant Gear Character in Runway
        Text {
            id: gearText
            anchors.horizontalCenter: parent.horizontalCenter
            y: 308
            text: root.gearLabel
            color: "#ffffff"
            font.family: root.menuFont; font.bold: true; font.pixelSize: 68
        }
        Text {
            anchors.top: gearText.bottom; anchors.topMargin: -6
            anchors.horizontalCenter: parent.horizontalCenter
            text: "GEAR"
            color: "#4fc3f7"
            font.family: root.menuFont; font.bold: true; font.pixelSize: 12
            font.letterSpacing: 1
        }
    }

    // =======================================================================
    //  LEFT SECTION: TEMP (IAT, COOLANT, AFR) & FUEL POD
    //  Tucked tightly to left (x: 35..235) with numbers snug beside the bars
    // =======================================================================
    Item {
        id: leftSection
        x: 35; y: 0; width: 200; height: 480

        // Header: LIVE
        Text {
            x: 0; y: 84
            text: "LIVE"
            color: "#ffffff"
            font.family: root.menuFont; font.bold: true; font.pixelSize: 13
            font.letterSpacing: 1
        }

        // -------------------------------------------------------------
        // Row 1: IAT (Intake Air Temp / oiltempdata)
        // -------------------------------------------------------------
        Item {
            x: 0; y: 114; width: 200; height: 48
            visible: root.showOilTemp

            Text {
                x: 0; y: 2; width: 54
                text: "OIL TEMP"
                color: "#4fc3f7"
                font.family: root.menuFont; font.bold: true; font.pixelSize: 11
            }

            // Snug 90px Segmented Bar (8 Segments)
            Item {
                x: 58; y: 0; width: 90; height: 18
                Rectangle {
                    anchors.fill: parent
                    color: "#051322"; border.color: "#0d3659"; border.width: 1; radius: 2
                }

                readonly property real valFrac: {
                    var f = (root.oiltemp - root.oilTempLow) / Math.max(1, root.oilTempHigh - root.oilTempLow);
                    var realF = Math.max(0, Math.min(1, f));
                    return root.selfTest ? (root.sweepFrac * (1 - root.settle) + realF * root.settle) : realF;
                }
                readonly property int activeSegs: Math.round(valFrac * 8)

                Row {
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        model: 8
                        Rectangle {
                            width: 8.8; height: 12; radius: 1
                            readonly property bool isLit: index < parent.parent.activeSegs
                            readonly property bool isWarn: root.oiltemp >= root.oilTempHigh
                            color: isLit ? (isWarn ? "#ff3344" : "#1eb8ff") : "#081829"
                            border.color: isLit ? "#ffffff" : "transparent"
                            border.width: (isLit && index === parent.parent.activeSegs - 1) ? 1 : 0
                        }
                    }
                }
            }

            // Numeric Value readout positioned right beside bar
            Text {
                x: 140; y: 2; width: 44
                text: fmtTemp(root.oiltemp, root.oilTempUnits)
                color: (root.oiltemp >= root.oilTempHigh) ? "#ff4444" : "#ffffff"
                font.family: root.menuFont; font.bold: true; font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
            }

            // Min / Max indicators
            Text { x: 58; y: 20; text: "C"; color: "#2d618c"; font.family: root.menuFont; font.pixelSize: 9; font.bold: true }
            Text { x: 140; y: 20; text: "H"; color: "#2d618c"; font.family: root.menuFont; font.pixelSize: 9; font.bold: true }
        }

        // -------------------------------------------------------------
        // Row 2: COOLANT (Watertemp data)
        // -------------------------------------------------------------
        Item {
            x: 0; y: 164; width: 200; height: 48
            visible: root.showCoolant

            Text {
                x: 0; y: 2; width: 54
                text: "COOLANT"
                color: "#4fc3f7"
                font.family: root.menuFont; font.bold: true; font.pixelSize: 10
            }

            // Snug 90px Segmented Bar (8 Segments)
            Item {
                x: 58; y: 0; width: 90; height: 18
                Rectangle {
                    anchors.fill: parent
                    color: "#051322"; border.color: "#0d3659"; border.width: 1; radius: 2
                }

                readonly property real valFrac: {
                    var f = (root.watertemp - root.coolantLow) / Math.max(1, root.coolantHigh - root.coolantLow);
                    var realF = Math.max(0, Math.min(1, f));
                    return root.selfTest ? (root.sweepFrac * (1 - root.settle) + realF * root.settle) : realF;
                }
                readonly property int activeSegs: Math.round(valFrac * 8)

                Row {
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        model: 8
                        Rectangle {
                            width: 8.8; height: 12; radius: 1
                            readonly property bool isLit: index < parent.parent.activeSegs
                            readonly property bool isWarn: root.watertemp >= root.coolantHigh
                            color: isLit ? (isWarn ? "#ff3344" : "#1eb8ff") : "#081829"
                            border.color: isLit ? "#ffffff" : "transparent"
                            border.width: (isLit && index === parent.parent.activeSegs - 1) ? 1 : 0
                        }
                    }
                }
            }

            // Numeric Value readout
            Text {
                x: 140; y: 2; width: 44
                text: fmtTemp(root.watertemp, root.tempunits)
                color: (root.watertemp >= root.coolantHigh) ? "#ff4444" : "#ffffff"
                font.family: root.menuFont; font.bold: true; font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
            }

            Text { x: 58; y: 20; text: "C"; color: "#2d618c"; font.family: root.menuFont; font.pixelSize: 9; font.bold: true }
            Text { x: 140; y: 20; text: "H"; color: "#2d618c"; font.family: root.menuFont; font.pixelSize: 9; font.bold: true }
        }

        // -------------------------------------------------------------
        // Row 3: AFR / LAMBDA (O2 data)
        // -------------------------------------------------------------
        Item {
            x: 0; y: 214; width: 200; height: 48
            visible: root.showAfr

            Text {
                x: 0; y: 2; width: 54
                text: root.afrSource === 1 ? "LAMBDA" : "AFR"
                color: "#4fc3f7"
                font.family: root.menuFont; font.bold: true; font.pixelSize: 10
            }

            // Snug 90px Segmented Bar (8 Segments)
            Item {
                x: 58; y: 0; width: 90; height: 18
                Rectangle {
                    anchors.fill: parent
                    color: "#051322"; border.color: "#0d3659"; border.width: 1; radius: 2
                }

                readonly property real valFrac: {
                    var l = root.afr / 14.7;
                    // Fixed Lambda scale: 0.80 left, 1.00 centre, 1.20 right.
                    // Warning limits remain configurable separately.
                    var f = (l - 0.80) / 0.40;
                    var realF = Math.max(0, Math.min(1, f));
                    return root.selfTest ? (root.sweepFrac * (1 - root.settle) + realF * root.settle) : realF;
                }
                readonly property int activeSegs: Math.round(valFrac * 8)

                Row {
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        model: 8
                        Rectangle {
                            width: 8.8; height: 12; radius: 1
                            readonly property bool isLit: index < parent.parent.activeSegs
                            readonly property bool isWarn: {
                                var curL = root.afr / 14.7;
                                return curL < root.afrLow || curL > root.afrHigh;
                            }
                            color: isLit ? (isWarn ? "#ff3344" : "#1eb8ff") : "#081829"
                        }
                    }
                }
            }

            // Numeric Value readout
            Text {
                x: 140; y: 2; width: 44
                text: root.afrSource === 1 ? (root.afr / 14.7).toFixed(2) : root.afr.toFixed(1)
                color: "#ffffff"
                font.family: root.menuFont; font.bold: true; font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
            }

            Row {
                x: 58; y: 20; width: 90; height: 12
                Text { width: 30; text: "0.80"; color: "#2d618c"; font.family: root.menuFont; font.pixelSize: 8; font.bold: true; horizontalAlignment: Text.AlignLeft }
                Text { width: 30; text: "1.00"; color: "#ffffff"; font.family: root.menuFont; font.pixelSize: 8; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                Text { width: 30; text: "1.20"; color: "#2d618c"; font.family: root.menuFont; font.pixelSize: 8; font.bold: true; horizontalAlignment: Text.AlignRight }
            }
        }

        // -------------------------------------------------------------
        // Lower-Left: FUEL Pod (Exact Vertical Alignment with SPEED at y: 290)
        // -------------------------------------------------------------
        Item {
            id: fuelPod
            x: 0; y: 290; width: 200; height: 124

            Text {
                anchors.top: parent.top; anchors.topMargin: 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: "FUEL"
                color: "#ffffff"
                font.family: root.menuFont; font.bold: true; font.pixelSize: 12
                font.letterSpacing: 1
            }

            // Circular Fuel Gauge Pod
            Item {
                id: fuelRing
                anchors.top: parent.top; anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                width: 78; height: 78

                // Dark circular background
                Rectangle {
                    anchors.fill: parent; radius: 39
                    color: "#040e1a"; border.color: "#0c2b48"; border.width: 1.5
                }

                // Sweeping Arc spokes for Fuel Ring
                Repeater {
                    model: 24
                    Rectangle {
                        readonly property real deg: 135 + (index / 24) * 270
                        readonly property real rad: deg * Math.PI / 180
                        readonly property bool lit: index < Math.round(root.fuelBarFrac * 24)
                        readonly property bool warn: root.fuelLevel < root.fuelLow
                        width: 4; height: 8; radius: 1
                        color: lit ? (warn ? "#ff3344" : "#1eb8ff") : "#071728"
                        x: 39 + 30 * Math.cos(rad) - width/2
                        y: 39 + 30 * Math.sin(rad) - height/2
                        transformOrigin: Item.Center
                        rotation: deg + 90
                    }
                }

                // Inner Pod Cutout
                Rectangle {
                    anchors.centerIn: parent
                    width: 48; height: 48; radius: 24
                    color: "#030a14"
                    border.color: "#0a2238"; border.width: 1
                }

                // Center Percentage Text
                Text {
                    anchors.centerIn: parent
                    text: Math.round(root.fuelLevel) + "%"
                    color: (root.fuelLevel < root.fuelLow) ? "#ff5555" : "#ffffff"
                    font.family: root.menuFont; font.bold: true; font.pixelSize: 15
                }
            }
        }
    }

    // =======================================================================
    //  RIGHT SECTION: PEAKS (RPM, SPEED, IAT, LAMBDA) & SPEED POD
    //  Spaced safely away from tach sweep at x: 565..765
    // =======================================================================
    Item {
        id: rightSection
        x: 565; y: 0; width: 200; height: 480

        // Header: PEAKS (Matching TEMP)
        Text {
            x: 0; y: 84
            text: "PEAKS"
            color: "#ffffff"
            font.family: root.menuFont; font.bold: true; font.pixelSize: 13
            font.letterSpacing: 1
        }

        // -------------------------------------------------------------
        // -------------------------------------------------------------
        // PEAKS TABLE: Label | MIN | MAX  (compact, no bars)
        // -------------------------------------------------------------
        Item {
            x: 0; y: 108; width: 200; height: 140

            // Column headers
            Text { x: 20;  y: 0; text: "";      color: "#4fc3f7"; font.family: root.menuFont; font.bold: true; font.pixelSize: 8 }
            Text { x: 88; y: 0; text: "LOW";   color: "#4fc3f7"; font.family: root.menuFont; font.bold: true; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; width: 50 }
            Text { x: 154; y: 0; text: "HIGH";  color: "#4fc3f7"; font.family: root.menuFont; font.bold: true; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; width: 50 }

            // Divider
            Rectangle { x: 20; y: 12; width: 184; height: 1; color: "#0d3659" }

            // Row 1: RPM
            Text { x: 20;  y: 18; text: "RPM";  color: "#4fc3f7"; font.family: root.menuFont; font.bold: true; font.pixelSize: 11 }
            Text {
                x: 88; y: 16; width: 50
                text: root.peakRpmMin < 1e8 ? String(Math.round(root.peakRpmMin)) : "--"
                color: "#8aa5c7"; font.family: root.menuFont; font.bold: true; font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
            }
            Text {
                x: 154; y: 16; width: 50
                text: root.peakRpm > 0 ? String(Math.round(root.peakRpm)) : "--"
                color: "#ffffff"; font.family: root.menuFont; font.bold: true; font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
            }

            // Row divider
            Rectangle { x: 20; y: 32; width: 162; height: 1; color: "#051322" }

            // Row 2: SPEED
            Text { x: 20;  y: 38; text: "SPEED"; color: "#4fc3f7"; font.family: root.menuFont; font.bold: true; font.pixelSize: 11 }
            Text {
                x: 88; y: 36; width: 50
                text: root.peakSpeedMin < 1e8 ? String(Math.round(root.speedunits === 0 ? root.peakSpeedMin : root.peakSpeedMin * 0.621371)) : "--"
                color: "#8aa5c7"; font.family: root.menuFont; font.bold: true; font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
            }
            Text {
                x: 154; y: 36; width: 50
                text: root.peakSpeed > 0 ? String(Math.round(root.speedunits === 0 ? root.peakSpeed : root.peakSpeed * 0.621371)) : "--"
                color: "#ffffff"; font.family: root.menuFont; font.bold: true; font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
            }

            // Row divider
            Rectangle { x: 20; y: 52; width: 162; height: 1; color: "#051322" }

            // Row 3: IAT
            Text { x: 20;  y: 58; text: "OIL TEMP";  color: "#4fc3f7"; font.family: root.menuFont; font.bold: true; font.pixelSize: 11 }
            Text {
                x: 88; y: 56; width: 50
                text: root.peakOilTempMin < 1e8 ? fmtTemp(root.peakOilTempMin, root.oilTempUnits) : "--"
                color: "#8aa5c7"; font.family: root.menuFont; font.bold: true; font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
            }
            Text {
                x: 154; y: 56; width: 50
                text: root.peakOilTemp > -1e8 ? fmtTemp(root.peakOilTemp, root.oilTempUnits) : "--"
                color: (root.peakOilTemp >= root.oilTempHigh) ? "#ff4444" : "#ffffff"
                font.family: root.menuFont; font.bold: true; font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
            }

            // Row divider
            Rectangle { x: 20; y: 72; width: 162; height: 1; color: "#051322" }

            // Row 4: λ / AFR
            Text { x: 20;  y: 78; text: root.afrSource === 1 ? "\u03BB" : "AFR"; color: "#4fc3f7"; font.family: root.menuFont; font.bold: true; font.pixelSize: 11 }
            Text {
                x: 88; y: 76; width: 50
                text: root.peakAfrMin < 1e8 ? (root.afrSource === 1 ? (root.peakAfrMin / 14.7).toFixed(2) : root.peakAfrMin.toFixed(1)) : "--"
                color: "#8aa5c7"; font.family: root.menuFont; font.bold: true; font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
            }
            Text {
                x: 154; y: 76; width: 50
                text: root.peakAfrMax > -1e8 ? (root.afrSource === 1 ? (root.peakAfrMax / 14.7).toFixed(2) : root.peakAfrMax.toFixed(1)) : "--"
                color: "#ffffff"; font.family: root.menuFont; font.bold: true; font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
            }

            // Bottom divider
            Rectangle { x: 20; y: 92; width: 162; height: 1; color: "#0d3659" }
        }


        // -------------------------------------------------------------
        // Bottom-Right: SPEED Pod (Exact Vertical Alignment with FUEL at y: 290)
        // -------------------------------------------------------------
        Item {
            id: speedPod
            x: 0; y: 290; width: 200; height: 124

            Text {
                anchors.top: parent.top; anchors.topMargin: 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: "SPEED"
                color: "#4fc3f7"
                font.family: root.menuFont; font.bold: true; font.pixelSize: 12
                font.letterSpacing: 1
            }

            // Giant Speed Digits
            Text {
                id: speedDigits
                anchors.top: parent.top; anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.engineOff ? "---" : String(root.speedShown)
                color: root.engineOff ? "#3d546e" : "#ffffff"
                font.family: root.menuFont; font.bold: true; font.pixelSize: 62
            }

            // Speed Unit (mph / kph)
            Text {
                anchors.top: speedDigits.bottom; anchors.topMargin: -6
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.speedUnit
                color: "#4fc3f7"
                font.family: root.menuFont; font.bold: true; font.pixelSize: 14
            }
        }
    }

    // =======================================================================
    //  BOTTOM BAR: BATTERY, TELLTALES, ODO / TRIP
    // =======================================================================
    Item {
        id: bottomBar
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: 52

        // Battery Voltage (Left)
        Item {
            x: 24; y: 14; width: 120; height: 26
            readonly property bool warn: root.batteryShown < root.batteryLow || root.batteryShown > root.batteryHigh

            // Battery Outline Icon
            Rectangle {
                x: 0; y: 4; width: 22; height: 13; color: "transparent"
                border.color: parent.warn ? "#ff4444" : "#1eb8ff"; border.width: 1.5; radius: 1
            }
            Rectangle {
                x: 22; y: 7; width: 2; height: 7
                color: parent.warn ? "#ff4444" : "#1eb8ff"
            }
            // Battery Voltage Text
            Text {
                x: 30; y: 2
                text: root.batteryShown > 0 ? root.batteryShown.toFixed(1) + "V" : "--.-V"
                color: parent.warn ? "#ff6666" : "#ffffff"
                font.family: root.menuFont; font.bold: true; font.pixelSize: 14
            }
        }

        // Telltale Icon Row (Center)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Repeater {
                model: [
                    { src: "high_beam",            bit: 0x10 },
                    { src: "sidelight",            bit: 0x800 },
                    { src: "rear_fog",             bit: 0x08 },
                    { src: "brake_warning",        bit: 0x8000100 },
                    { src: "oil_pressure_warning", bit: 0x200 },
                    { src: "battery_warning",      bit: 0x02 },
                    { src: "seatbelt_warning",     bit: 0x400 },
                    { src: "abs_warning",          bit: 0x20000 },
                    { src: "tc_warning",           bit: 0x10000 },
                    { src: "mil_warning",          bit: 0x40000 },
                    { src: "airbag_warning",       bit: 0x8000 },
                    { src: "door_open",            bit: 0x4000 }
                ]
                Item {
                    height: 20
                    width: ttImg.width
                    readonly property bool isTc: modelData.src === "tc_warning"
                    readonly property bool tcOff: (root.inputs & 0x10000000) !== 0
                    Image {
                        id: ttImg
                        source: "assets/" + modelData.src + ".png"
                        height: 20
                        width: Math.min(32, implicitHeight > 0 ? 20 * implicitWidth / implicitHeight : 28)
                        fillMode: Image.PreserveAspectFit; smooth: true; antialiasing: true
                        opacity: (root.selfTest || (root.inputs & modelData.bit) || (parent.isTc && parent.tcOff)) ? 1.0 : 0.18
                    }
                }
            }
        }

        // Odometer & Trip (Right)
        Item {
            anchors.right: parent.right; anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: 130; height: 34

            Text {
                anchors.right: parent.right; y: 0
                text: "ODO " + Math.round(root.odometer * root.distFactor) + root.distUnit
                color: "#c9d6ee"; font.family: root.menuFont; font.bold: true; font.pixelSize: 11
            }
            Text {
                anchors.right: parent.right; y: 16
                text: "TRIP " + Math.round(root.tripmeter * root.distFactor) + root.distUnit
                color: "#8aa5c7"; font.family: root.menuFont; font.bold: true; font.pixelSize: 11
            }
        }
    }

    // =======================================================================
    //  FILEIO & CONFIG PERSISTENCE
    // =======================================================================
    FileIO { id: cfg; source: root.cfgPath }
    property string cfgPath: "/opt/IC7/screen_configs/DDUDash.txt"
    property var cfgCandidates: [
        "/opt/Garw_IC7/screen_configs/DDUDash.txt",
        "/opt/IC7/screen_configs/DDUDash.txt",
        "/home/root/DDUDash.txt"
    ]

    function rline(i) {
        cfg.openforreading();
        var s = cfg.readopenfile(i);
        cfg.close();
        return s;
    }
    function resolveCfgPath() {
        var i, s;
        for (i = 0; i < root.cfgCandidates.length; i++) {
            root.cfgPath = root.cfgCandidates[i];
            s = rline(0);
            if (s !== "" && s !== undefined && s !== null) return;
        }
        for (i = 0; i < root.cfgCandidates.length; i++) {
            root.cfgPath = root.cfgCandidates[i];
            saveConfig();
            s = rline(0);
            if (s !== "" && s !== undefined && s !== null) return;
        }
        root.cfgPath = root.cfgCandidates[root.cfgCandidates.length - 1];
    }
    function loadConfig() {
        function pI(s, def) { return (s !== "" && s !== undefined && s !== null) ? parseInt(s)   : def; }
        function pF(s, def) { return (s !== "" && s !== undefined && s !== null) ? parseFloat(s) : def; }
        var s0 = rline(0);
        var found = (s0 !== "" && s0 !== undefined && s0 !== null);
        if (!found) return false;
        root.red          = pI(s0,         root.red);
        root.green        = pI(rline(1),   root.green);
        root.blue         = pI(rline(2),   root.blue);
        root.rpmredline   = pI(rline(3),   root.rpmredline);
        root.rpmmax       = pI(rline(4),   root.rpmmax);
        root.rpmDamp      = pI(rline(5),   root.rpmDamp);
        root.speedunits   = pI(rline(6),   root.speedunits);
        root.distunits    = pI(rline(7),   root.distunits);
        root.coolantHigh  = pF(rline(8),   root.coolantHigh);
        root.coolantLow   = pF(rline(9),   root.coolantLow);
        root.tempunits    = pI(rline(10),  root.tempunits);
        root.fuelHigh     = pI(rline(11),  root.fuelHigh);
        root.fuelLow      = pI(rline(12),  root.fuelLow);
        root.fuelDamp     = pI(rline(13),  root.fuelDamp);
        root.oilTempHigh  = pF(rline(14),  root.oilTempHigh);
        root.oilTempLow   = pF(rline(15),  root.oilTempLow);
        root.oilTempUnits = pI(rline(16),  root.oilTempUnits);
        root.oilPressHigh = pF(rline(17),  root.oilPressHigh);
        root.oilPressLow  = pF(rline(18),  root.oilPressLow);
        root.oilPressUnits= pI(rline(19),  root.oilPressUnits);
        root.batteryHigh  = pF(rline(20),  root.batteryHigh);
        root.batteryLow   = pF(rline(21),  root.batteryLow);
        root.afrHigh      = pF(rline(22),  root.afrHigh);
        root.afrLow       = pF(rline(23),  root.afrLow);
        root.nightlight   = pI(rline(24),  root.nightlight);
        root.afrSource    = pI(rline(25),  root.afrSource);
        root.placementSwap= pI(rline(26),  root.placementSwap ? 1 : 0) !== 0;
        root.hideTachNums = pI(rline(27),  root.hideTachNums ? 1 : 0) !== 0;
        root.hideShiftLights = pI(rline(28), root.hideShiftLights ? 1 : 0) !== 0;
        root.showPeakGauge   = pI(rline(29), root.showPeakGauge ? 1 : 0) !== 0;
        root.peakGaugePosition = pI(rline(30), root.peakGaugePosition);
        root.peakShowRpm      = pI(rline(31), root.peakShowRpm      ? 1 : 0) !== 0;
        root.peakShowSpeed    = pI(rline(32), root.peakShowSpeed    ? 1 : 0) !== 0;
        root.peakShowAfr      = pI(rline(33), root.peakShowAfr      ? 1 : 0) !== 0;
        root.peakShowOilTemp  = pI(rline(34), root.peakShowOilTemp  ? 1 : 0) !== 0;
        root.peakShowOilPress = pI(rline(35), root.peakShowOilPress ? 1 : 0) !== 0;
        root.peakShowCoolant  = pI(rline(36), root.peakShowCoolant  ? 1 : 0) !== 0;
        return found;
    }
    function saveConfig() {
        try {
            var vals = [root.red, root.green, root.blue, root.rpmredline, root.rpmmax,
                        root.rpmDamp, root.speedunits, root.distunits, root.coolantHigh.toFixed(1),
                        root.coolantLow.toFixed(1), root.tempunits, root.fuelHigh, root.fuelLow,
                        root.fuelDamp, root.oilTempHigh.toFixed(1), root.oilTempLow.toFixed(1), root.oilTempUnits,
                        root.oilPressHigh.toFixed(1), root.oilPressLow.toFixed(1), root.oilPressUnits,
                        root.batteryHigh.toFixed(1), root.batteryLow.toFixed(1),
                        root.afrHigh.toFixed(2), root.afrLow.toFixed(2), root.nightlight,
                        root.afrSource, (root.placementSwap ? 1 : 0), (root.hideTachNums ? 1 : 0),
                        (root.hideShiftLights ? 1 : 0),
                        (root.showPeakGauge ? 1 : 0), root.peakGaugePosition,
                        (root.peakShowRpm ? 1 : 0), (root.peakShowSpeed ? 1 : 0),
                        (root.peakShowAfr ? 1 : 0), (root.peakShowOilTemp ? 1 : 0),
                        (root.peakShowOilPress ? 1 : 0), (root.peakShowCoolant ? 1 : 0)];
            var out = "";
            for (var i = 0; i < vals.length; i++) out += String(vals[i]) + "\n";
            cfg.open();
            cfg.writetoopenfile(out);
            cfg.close();
        } catch (e) { console.log("GTDash: could not write config (" + e + ")"); }
    }

    Component.onCompleted: {
        if (root.d) { try { root.d.DISABLE_WARNING_OVERLAY = "YES_WARNINGS_HANDLED_LOCALLY"; } catch (e) {} }
        resolveCfgPath();
        if (!loadConfig()) saveConfig();
        if (root.rpmmax < 9000) root.rpmmax = 9000;
        if (root.rpmredline < 8000) root.rpmredline = 8750;
        fuelDisplay = fuel;
        oilPressShown = oilpress;
        bootSweep.start();
    }

    // =======================================================================
    //  D-PAD INPUT & SETTINGS MENU SYSTEM (250 RPM integer steps)
    // =======================================================================
    function udp()    { return (root.d && root.d.udp_packetdata !== undefined) ? root.d.udp_packetdata : 0; }
    function dUp()    { return ((root.inputs & 0x20) !== 0)       || ((udp() & 0x01) !== 0); }
    function dDown()  { return ((root.inputs & 0x2000) !== 0)     || ((udp() & 0x02) !== 0); }
    function dLeft()  { return ((root.inputs & 0x20000000) !== 0) || ((udp() & 0x04) !== 0); }
    function dRight() { return ((root.inputs & 0x40000000) !== 0) || ((udp() & 0x08) !== 0); }

    property bool menuOpen: false
    property int  sel: 0
    property int  settingsRev: 0
    property real pulse: 0
    property bool pUp: false
    property bool pDown: false
    property bool pLeft: false
    property bool pRight: false
    property int  upHold: 0
    property int  downHold: 0
    property bool upArmed: false
    property bool downArmed: false

    readonly property var menuRows: [
        { k: "red",           label: "RED" },
        { k: "green",         label: "GREEN" },
        { k: "blue",          label: "BLUE" },
        { k: "rpmredline",    label: "SHIFT RPM" },
        { k: "rpmmax",        label: "RPM LIMIT" },
        { k: "rpmDamp",       label: "RPM DAMPING" },
        { k: "speedunits",    label: "SPEED UNITS" },
        { k: "distunits",     label: "DIST UNITS" },
        { k: "coolantHigh",   label: "COOLANT HIGH" },
        { k: "coolantLow",    label: "COOLANT LOW" },
        { k: "tempunits",     label: "COOLANT UNITS" },
        { k: "fuelHigh",      label: "FUEL HIGH" },
        { k: "fuelLow",       label: "FUEL LOW" },
        { k: "fuelDamp",      label: "FUEL DAMP" },
        { k: "oilTempHigh",   label: "OIL TEMP HIGH" },
        { k: "oilTempLow",    label: "OIL TEMP LOW" },
        { k: "oilTempUnits",  label: "OIL TEMP UNITS" },
        { k: "oilPressHigh",  label: "OIL PRESS HIGH" },
        { k: "oilPressLow",   label: "OIL PRESS LOW" },
        { k: "oilPressUnits", label: "OIL PRESS UNITS" },
        { k: "batteryHigh",   label: "BATTERY HIGH" },
        { k: "batteryLow",    label: "BATTERY LOW" },
        { k: "afrHigh",       label: "AFR HIGH" },
        { k: "afrLow",        label: "AFR LOW" },
        { k: "afrSource",     label: "AFR DISPLAY" },
        { k: "nightlight",    label: "NIGHTLIGHT" },
        { k: "exit",          label: "EXIT & SAVE" }
    ]

    function getVal(k) {
        if (k === "red")           return String(root.red);
        if (k === "green")         return String(root.green);
        if (k === "blue")          return String(root.blue);
        if (k === "rpmredline")    return String(Math.round(root.rpmredline));
        if (k === "rpmmax")        return String(Math.round(root.rpmmax));
        if (k === "rpmDamp")       return String(root.rpmDamp);
        if (k === "speedunits")    return root.speedunits === 0 ? "KM/H" : "MPH";
        if (k === "distunits")     return root.distunits  === 0 ? "KM"   : "MILES";
        if (k === "coolantHigh")   return root.coolantHigh.toFixed(0) + " C";
        if (k === "coolantLow")    return root.coolantLow.toFixed(0) + " C";
        if (k === "tempunits")     return root.tempunits === 0 ? "CELSIUS" : "FAHRENHEIT";
        if (k === "fuelHigh")      return String(root.fuelHigh) + " %";
        if (k === "fuelLow")       return String(root.fuelLow) + " %";
        if (k === "fuelDamp")      return String(root.fuelDamp);
        if (k === "oilTempHigh")   return root.oilTempHigh.toFixed(0) + " C";
        if (k === "oilTempLow")    return root.oilTempLow.toFixed(0) + " C";
        if (k === "oilTempUnits")  return root.oilTempUnits === 0 ? "CELSIUS" : root.oilTempUnits === 1 ? "FAHRENHEIT" : "OFF";
        if (k === "oilPressHigh")  return root.oilPressHigh.toFixed(0) + " PSI";
        if (k === "oilPressLow")   return root.oilPressLow.toFixed(0) + " PSI";
        if (k === "oilPressUnits") return root.oilPressUnits === 0 ? "PSI" : root.oilPressUnits === 1 ? "BAR" : "OFF";
        if (k === "batteryHigh")   return root.batteryHigh.toFixed(1) + " V";
        if (k === "batteryLow")    return root.batteryLow.toFixed(1) + " V";
        if (k === "afrHigh")       return root.afrHigh.toFixed(2);
        if (k === "afrLow")        return root.afrLow.toFixed(2);
        if (k === "afrSource")     return root.afrSource === 0 ? "AFR" : root.afrSource === 1 ? "LAMBDA" : "OFF";
        if (k === "nightlight")    return String(root.nightlight) + " %";
        if (k === "exit")          return "UP TO SAVE";
        return "";
    }

    function modVal(k, dir) {
        if (k === "red")           root.red = Math.max(0, Math.min(255, root.red + dir * 5));
        else if (k === "green")    root.green = Math.max(0, Math.min(255, root.green + dir * 5));
        else if (k === "blue")     root.blue = Math.max(0, Math.min(255, root.blue + dir * 5));
        else if (k === "rpmredline") root.rpmredline = Math.round(Math.max(2000, Math.min(12000, root.rpmredline + dir * 250)));
        else if (k === "rpmmax")   { root.rpmmax = Math.round(Math.max(3000, Math.min(14000, root.rpmmax + dir * 250))); bg.requestPaint(); }
        else if (k === "rpmDamp")  root.rpmDamp = Math.max(1, Math.min(10, root.rpmDamp + dir));
        else if (k === "speedunits") root.speedunits = root.speedunits === 0 ? 1 : 0;
        else if (k === "distunits")  root.distunits = root.distunits === 0 ? 1 : 0;
        else if (k === "coolantHigh") root.coolantHigh = Math.max(60, Math.min(140, root.coolantHigh + dir));
        else if (k === "coolantLow")  root.coolantLow = Math.max(20, Math.min(90, root.coolantLow + dir));
        else if (k === "tempunits")   root.tempunits = root.tempunits === 0 ? 1 : 0;
        else if (k === "fuelHigh")    root.fuelHigh = Math.max(50, Math.min(100, root.fuelHigh + dir * 5));
        else if (k === "fuelLow")     root.fuelLow = Math.max(5, Math.min(40, root.fuelLow + dir));
        else if (k === "fuelDamp")    root.fuelDamp = Math.max(0, Math.min(9, root.fuelDamp + dir));
        else if (k === "oilTempHigh") root.oilTempHigh = Math.max(70, Math.min(160, root.oilTempHigh + dir));
        else if (k === "oilTempLow")  root.oilTempLow = Math.max(20, Math.min(100, root.oilTempLow + dir));
        else if (k === "oilTempUnits") { root.oilTempUnits = (root.oilTempUnits + dir + 3) % 3; bg.requestPaint(); }
        else if (k === "oilPressHigh") root.oilPressHigh = Math.max(30, Math.min(150, root.oilPressHigh + dir * 5));
        else if (k === "oilPressLow")  root.oilPressLow = Math.max(5, Math.min(50, root.oilPressLow + dir));
        else if (k === "oilPressUnits") { root.oilPressUnits = (root.oilPressUnits + dir + 3) % 3; bg.requestPaint(); }
        else if (k === "batteryHigh") root.batteryHigh = Math.max(12.0, Math.min(16.0, root.batteryHigh + dir * 0.1));
        else if (k === "batteryLow")  root.batteryLow = Math.max(9.0, Math.min(13.0, root.batteryLow + dir * 0.1));
        else if (k === "afrHigh")     root.afrHigh = Math.max(0.8, Math.min(1.4, root.afrHigh + dir * 0.01));
        else if (k === "afrLow")      root.afrLow = Math.max(0.6, Math.min(1.2, root.afrLow + dir * 0.01));
        else if (k === "afrSource")   { root.afrSource = (root.afrSource + dir + 3) % 3; bg.requestPaint(); }
        else if (k === "nightlight")   root.nightlight = Math.max(10, Math.min(100, root.nightlight + dir * 5));
        root.settingsRev++;
    }

    function evalEdges() {
        var u = dUp(), d = dDown(), l = dLeft(), r = dRight();
        var roseU = u && !pUp, roseD = d && !pDown;
        var roseL = l && !pLeft, roseR = r && !pRight;

        if (d) {
            downHold++;
            if (downHold === 30 && !menuOpen) {
                resetPeaks();
            }
        } else {
            downHold = 0;
        }

        if (!menuOpen) {
            if (roseU) {
                menuOpen = true;
                if (root.d) { try { root.d.settings_on_offdata = 1; } catch (e) {} }
            }
        } else {
            if (roseL) { sel = (sel - 1 + menuRows.length) % menuRows.length; }
            if (roseR) { sel = (sel + 1) % menuRows.length; }
            if (roseU) {
                if (menuRows[sel].k === "exit") {
                    saveConfig();
                    menuOpen = false;
                    if (root.d) { try { root.d.settings_on_offdata = 0; } catch (e) {} }
                } else {
                    modVal(menuRows[sel].k, 1);
                }
            }
            if (roseD) {
                modVal(menuRows[sel].k, -1);
            }
        }

        // mirror the flasher/bulb state (poll-driven; robust on backends that
        // don't emit change signals)
        root.tLeftActive  = ((root.inputs & 0x40) !== 0);
        root.tRightActive = ((root.inputs & 0x80) !== 0);
        pUp = u; pDown = d; pLeft = l; pRight = r;
    }

    Timer { interval: 40; repeat: true; running: true; onTriggered: evalEdges() }

    // ---- turn-signal arrows (top corners), blinking with the flasher relay ----
    Image {   // left indicator (inputsdata 0x40)
        source: "assets/left_indicator.png"
        x: 36; y: 39; height: 42; fillMode: Image.PreserveAspectFit; smooth: true
        visible: root.tLeftActive
    }
    Image {   // right indicator (inputsdata 0x80)
        source: "assets/right_indicator.png"
        anchors.right: parent.right; anchors.rightMargin: 36
        y: 39; height: 42; fillMode: Image.PreserveAspectFit; smooth: true
        visible: root.tRightActive
    }

    // =======================================================================
    //  SETTINGS MENU OVERLAY
    // =======================================================================
    Rectangle {
        id: menuOverlay
        anchors.fill: parent
        visible: root.menuOpen
        color: "#f0020712"
        z: 999

        Rectangle {
            anchors.centerIn: parent
            width: 520; height: 380; radius: 6
            color: "#051120"; border.color: "#1eb8ff"; border.width: 1.5

            Text {
                anchors.top: parent.top; anchors.topMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                text: "DDU 10 DASH SETTINGS"
                color: "#1eb8ff"
                font.family: root.menuFont; font.bold: true; font.pixelSize: 16
                font.letterSpacing: 2
            }

            ListView {
                id: menuList
                anchors.top: parent.top; anchors.topMargin: 46
                anchors.bottom: parent.bottom; anchors.bottomMargin: 46
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 20; anchors.rightMargin: 20
                clip: true
                model: root.menuRows
                currentIndex: root.sel
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    width: menuList.width; height: 32; radius: 3
                    readonly property bool isSelected: index === root.sel
                    color: isSelected ? "#0a3055" : (index % 2 === 0 ? "#030a14" : "transparent")
                    border.color: isSelected ? "#1eb8ff" : "transparent"
                    border.width: 1

                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: parent.isSelected ? "#ffffff" : "#7aa6cd"
                        font.family: root.menuFont; font.bold: true; font.pixelSize: 13
                    }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: { var dummy = root.settingsRev; return getVal(modelData.k); }
                        color: parent.isSelected ? "#1eb8ff" : "#d0e8ff"
                        font.family: root.menuFont; font.bold: true; font.pixelSize: 13
                    }
                }
            }

            Text {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\u25C0 \u25B6 MOVE   \u25B2 \u25BC CHANGE   EXIT ROW + \u25B2 SAVE & CLOSE"
                color: "#4a7a9e"
                font.family: root.menuFont; font.bold: true; font.pixelSize: 11
            }
        }
    }
}
