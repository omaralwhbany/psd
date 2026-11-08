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
