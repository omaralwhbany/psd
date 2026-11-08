# Buck waveform source audit

Scope: the non-synchronous Buck device graphs only. Source of truth is
`PSD5_java/com/ti/switchingpowersupplydesign/sheets/Buck.java` and the
matching class in `PSD5.jar`. This note records source inspection; the new
graph arrays are not claimed to be runtime output from Java graph methods.

## Original graph entry points

`Buck.getGraphsGraphics()` dispatches five graph windows:

| Device | Graph factory | Voltage/current point methods |
|---|---|---|
| Input capacitor Ci | `paintINCAP` | `incapCalcCCMVoltage/Current`, `incapCalcDCCMVoltage/Current` |
| MOSFET Q1 | `paintFET` | `fetCalcCCMVoltage/Current`, `fetCalcDCCMVoltage/Current` |
| Inductor L1 | `paintInductor` | `inductorCalcCCMVoltage/Current`, `inductorCalcDCCMVoltage/Current` |
| Diode D1 | `paintDiode` | `diodeCalcCCMVoltage/Current`, `diodeCalcDCCMVoltage/Current` |
| Output capacitor Co | `paintOUTCAP` | `outcapCalcCCMVoltage/Current`, `outcapCalcDCCMVoltage/Current` |

## Timing and sample count

`fillTimeScaleArrays()` builds 21 time samples using the exact `t1 + t2 + t3` cycle sum from
`fillTimeScaleArrays()`. It inserts a 1 ns offset on either side of switching
transitions and converts seconds to microseconds. In CCM, `t3` is itself the
1 ns numerical epsilon, so each plotted cycle is 1 ns longer than `1/fs`; in
DCM, `t1 + t2 + t3` sums to the switching period. `Graph` then copies arrays with length minus one in
both its constructor and `setPoints()`; therefore the original Swing graph
plots the first 20 points, not all 21. Flutter now preserves the source
21-point time base but renders the same first 20 samples.

## Source-defined device levels

- **Input capacitor:** voltage is `vin_calculation` in both modes; the DCM
  zero-current voltage field is also assigned the same input voltage. During
  ON, current runs from `iin - imin` to `iin - imax`; during OFF/idle the
  source uses `ifet_avg_buck`.
- **MOSFET:** voltage is 0 V during ON, `Vin + Vf` during diode conduction,
  and in DCM `Vin - Vo` after inductor current reaches zero. Current follows
  inductor current during ON and is zero while OFF.
- **Inductor:** voltage is `Vin - Vo` during ON, `-Vo - Vf` during diode
  conduction, and 0 V during the DCM zero-current interval. Current is the
  source's triangular CCM/DCM trace.
- **Diode:** voltage is `-Vin` while blocked, `Vf` while conducting, and
  `-Vo` during DCM zero-current time. Current is zero during ON, follows the
  inductor during diode conduction, and returns to zero in DCM idle time.
- **Output capacitor:** source graph voltage is constant `Vo` in both modes.
  Current is `iL - Iout`; in DCM it remains `-Iout` during zero-current time.

The source's constant capacitor-voltage traces and input-capacitor OFF-current
definition are retained even where a more detailed physical model might differ.

## Flutter coverage added

`buck_waveforms.dart` now builds the five paired voltage/current traces from
the Buck calculation output, using the source's CCM/DCM point patterns and
21-point time base. The UI shows all five device graphs and localizes device
names and voltage/current labels. Voltage/current axes use mV/mA when the
largest plotted magnitude is below 1, matching the unit selection in
`Graph.java`.

Regression tests use fixed numerical CCM/DCM oracle values captured from
previous actual executions of the original `PSD5.jar` calculation class.
The point-pattern mapping itself is source-derived from `Buck.java`; private
Java graph methods were not executed at runtime in this audit.

## Remaining graph parity work

The Swing `Graph` window includes sliders for input voltage and load current,
plus side labels for min/max, RMS, average and AC current. Flutter now exposes
a shared operating-input-voltage field and a shared 0..100% load slider in the
main Buck panel; these update all five device traces together rather than
creating five separate Swing graph windows. Numeric device metrics remain
shown beneath each trace instead of in the original side-label columns.
Device-graph data patterns and plotted sample count are covered, but visual
parity with the complete Swing graph window is not declared complete.


## Direct original-JAR graph-method runtime verification

The original PSD5.jar was loaded with OpenJDK 21 in headless mode. A
Buck instance was configured with the same fixed CCM and DCM test inputs,
then the private Java point methods for all five devices were invoked through
reflection. All 20 point-method executions (10 per operating mode: five voltage and five current) returned 21 points each. Their
sample values and time coordinates were compared against the independent
source transcription; every CCM and DCM trace matched. The original
Graph constructor and setPoints() were also checked: both copy only
points.length - 1, so the desktop UI plots 20 of the 21 source points.
This is an actual Java runtime execution of the private graph methods, not
merely a source-derived oracle.

The stable runtime comparison called calculate() twice after setting the
test inputs. This matters: userCalculate() calls actualValues() before
general(), while general() updates the iin field. Consequently the first
calculation after changing inputs can build the input-capacitor current
and RMS values with the previous calculation's iin; a second pass uses
the current value. Flutter currently uses the current pass's calculated input
average current. This transient, order-dependent first-pass behavior is
recorded as a known Java quirk rather than silently described as runtime
parity. The stable CCM/DCM graph arrays are now asserted point-by-point in
the Flutter regression suite.


## Buck current-ripple input validation

The Java source and JAR bytecode for `checkCurrentRipple()` were compared.
The original test is the strict condition
`iripple * 0.99 < dIout * dcurrent_ripple`; `iripple` is the actual
inductor current excursion (peak-to-valley in CCM, zero-to-peak in DCM).
A violation highlights the ripple input but does not abort the calculation.
Flutter now preserves the calculated values and reports this as a warning,
rather than marking the whole result invalid. CCM and DCM regression tests
cover the warning behavior, and the screen surfaces it in Arabic and English.


## GraphPanel axis and plotting geometry

The original GraphPanel source was checked for the plotted coordinate range.
It includes zero in one-sided Y ranges, places the horizontal axis at zero,
labels the top/middle/bottom Y values, and marks X positions at point indexes
0, 6, 12 and 18 plus the final plotted time. The Buck Flutter painter now
uses the same zero-inclusive range and tick positions, and labels the time
axis in microseconds. This is a source comparison of the original panel
geometry; no claim is made that the Flutter and Swing rasterization are pixel
identical.


## Checked-in original Java runtime graph fixture

A compact fixture at test/fixtures/buck_graph_java_oracle.json records the
first 20 plotted time/value samples from the original PSD5.jar runtime for
both fixed operating points and all five devices. It was captured by
reflectively invoking the original private Java graph methods after two
calculation passes with each input set, under OpenJDK 21 headless mode.
Flutter tests now read these fixed Java values directly; expected graph
samples and time coordinates are not derived from BuckEngine output.


The runtime fixture's boundary case uses the first representable
inductance on the CCM side of the nominal mathematical threshold:
`2.0270270270270273e-6 H`. The original Java runtime computes exactly
`10.0 A` for `iripple_buck`, equal to `2 * Iout`, so the source's
`<=` classifier selects CCM. The immediately smaller nominal-boundary
literal `2.027027027027027e-6 H` computes
`10.000000000000002 A` and selects DCM; the next smaller value
`2.0270270270270264e-6 H` computes `10.000000000000004 A` and also
selects DCM. These adjacent binary64 values were verified by invoking the
original PSD5.jar private calculation methods under OpenJDK 21 headless mode,
preserving the Java operation order. The checked-in boundary graph arrays
therefore intentionally contain CCM traces with zero valley current.


The runtime oracle fixture now also records the original Buck Java graph
label methods' minimum/maximum voltage and current, RMS, average, and AC
values for each device. The regression suite compares every displayed
metric to those original Java values. A CCM-only output-capacitor minimum
current label mismatch was corrected: Java uses `imin_ccm - Iout` in CCM
and `-Iout` in DCM.


The CCM/DCM classifier and minimum-inductance expression preserve the
original Java multiplication order (`1/fs * deltaV * duty * 1/L`), rather
than an algebraically equivalent rearrangement. At the nominal decimal
boundary, binary64 rounding places ripple at `10.000000000000002 A`, just
above the `10 A` threshold; the adjacent larger inductance used by the graph
fixture yields exactly `10 A` and remains CCM under the source's `<=`
condition. Regression tests cover both sides without changing the Java
inequality. The CCM output-capacitor minimum-current metric is checked against
Java's `imin_ccm - Iout` branch; `-Iout` applies only to DCM.


## Operating-load slider parity and Java runtime fixture

The original WorkingSheet source initializes `currentInputVoltage=0` and `currentLoadCurrent=100`. Its `setLoadCurrent()` method stores the slider percentage and calls `calculate()` twice. In `Buck.getUserValues()`, the rated output current `dIout` defines `ioutmin=0.01*dIout` and `ioutmax=dIout`. `Buck.checkForCCMDCCM()` then evaluates `currentLoadCurrent/100 * (ioutmax-ioutmin) + ioutmin`. Therefore slider positions 0%, 50%, and 100% mean 1%, 50.5%, and 100% of rated current, not 0%, 50%, and 100%.

This path was checked in both the extracted Java source and the original JAR bytecode (`WorkingSheet.setLoadCurrent`, `Buck.checkForCCMDCCM`, and `Graph.jSliderLoadCurrentStateChanged`). A headless OpenJDK 21 harness invoked the actual `Buck` class from `PSD5.jar`, set the same design inputs and slider positions, and called `calculate()` twice after each change. Fixed runtime values for the 18 V operating point, 12 V output, 5 A rated output, 200 kHz, 0.5 V diode drop, and 33 µH selected inductor were:

| Load slider | Actual load current | Mode | On time | Off time | Output power | Input power |
|---:|---:|---|---:|---:|---:|---:|
| 0% | 0.05 A | DCM | 1.3631243920156768 µs | 0.6542997081675247 µs | 0.60 W | 0.6081081081081082 W |
| 50% | 2.525 A | CCM | 3.3783783783783788 µs | 1.6216216216216216 µs | 30.30 W | 30.709459459459456 W |
| 100% | 5.00 A | CCM | 3.3783783783783788 µs | 1.6216216216216216 µs | 60.00 W | 60.810810810810814 W |

Flutter now carries `operatingLoadPercent` separately from rated `outputCurrent`. The minimum-inductance design and requested ripple limit continue to use the rated current, while CCM/DCM classification, power, device RMS/average values, and all five device waveforms use the interpolated operating load current. The new fixed-value regression test uses the values above from the actual Java runtime; the graph-shape regression is explicitly source-derived and is not described as an additional Java graph-method runtime comparison.
