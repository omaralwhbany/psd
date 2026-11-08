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

The Swing `Graph` window also includes slider controls for input voltage and
load current, and side labels for min/max, RMS, average and AC current. Flutter
currently keeps operating-point controls in the main Buck input panel and
shows the numeric device stresses in the results panel; it does not yet
recreate the separate Swing graph-window sliders or all of its side-label
layout. Device-graph data patterns and plotted sample count are covered, but
visual parity with the complete Swing graph window is not declared complete.


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


The boundary fixture preserves the exact Java UI conversion rather than
an idealized decimal threshold: `getUserModifiedValues()` parses the
inductance text in microhenries and divides by 1,000,000. The field text
`2.027027027027027` µH therefore becomes
`2.0270270270270273e-6` H on OpenJDK 21. The fixture records both values so
the source's `iripple_buck <= 2 * iout_calculation` equality is reproducible.

The runtime fixture also includes the exact CCM/DCM boundary. Buck.java uses
`iripple_buck <= 2 * iout_calculation`, so equality remains CCM. The
boundary fixture was generated by a separate headless PSD5.jar execution
with the critical inductance and confirms zero valley current in the CCM
graph methods.


The runtime oracle fixture now also records the original Buck Java graph
label methods' minimum/maximum voltage and current, RMS, average, and AC
values for each device. The regression suite compares every displayed
metric to those original Java values. A CCM-only output-capacitor minimum
current label mismatch was corrected: Java uses `imin_ccm - Iout` in CCM
and `-Iout` in DCM.


The CCM/DCM classifier and minimum-inductance expression now preserve the
original Java multiplication order (`1/fs * deltaV * duty * 1/L)), rather
than an algebraically equivalent rearrangement. This removes a floating
point edge discrepancy at the exact CCM boundary, where Buck.java uses
`iripple_buck <= 2 * iout_calculation`.
