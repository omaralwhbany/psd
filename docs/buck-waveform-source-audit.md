# Buck waveform source audit

Scope: the non-synchronous Buck device graphs only. Source of truth is
`PSD5_java/com/ti/switchingpowersupplydesign/sheets/Buck.java` and the
matching class in `PSD5.jar`. This note separates source-derived reconstruction details from direct runtime
checks. The checked-in graph fixture is from actual invocations of the
original Java graph methods under OpenJDK 21.

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
names and voltage/current labels. Voltage/current axes use mV/mA only when
every corresponding side-label value remains below 1 after the original
`DecimalFormat("#0.00####")` rounding in `Buck.java`. `Graph.java` parses those
formatted labels and switches to V/A when any absolute value is at least 1;
for example, 0.9999996 formats as 1.00. A NaN label also does not trigger
the switch because Java's `>= 1.0` comparison is false for NaN. Flutter now
preserves both cases instead of checking unrounded doubles.

Regression tests use fixed numerical CCM/DCM oracle values captured from
actual executions of the original `PSD5.jar` calculation class. The point-
pattern mapping itself is transcribed from `Buck.java` and is independently
checked against actual invocations of the private Java graph methods in the
runtime verification section below.

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


## ON/OFF time display units

The original `Buck.updateImportantOutput()` uses a strict `time < 1.0E-7` seconds test independently for ON and OFF time. Values below 100 ns are formatted as nanoseconds; values at or above 100 ns are formatted as microseconds. Both paths use two decimal places. Switching period and zero-current time always use microseconds with two decimals. This behavior was checked in the extracted `Buck.java` source (around line 865) and the `javap -p -c` bytecode for `updateImportantOutput()`. Flutter now follows the same threshold and precision; a widget regression covers 8.11 ns, 91.89 ns, and the exact 100 ns boundary.


## Main-panel actual ripple percentage

In `Buck.general()` (extracted source around line 714), PSD5 computes `iripple = iind_max - iind_min` and `iripplepercent = iripple / iout_calculation * 100.0`. The denominator is the interpolated operating load current, not the rated output-current input. The same expression is present in the original JAR bytecode for `general()`. A headless OpenJDK 21 probe of the original `Buck` class produced 495.68159709660966% at the 0% load-slider position (0.05 A, DCM) and 24.326757000024323% at 50% slider (2.525 A, CCM) for the fixed 18 V / 12 V, 5 A, 200 kHz, 0.5 V, 33 µH case. For the app's automatic-inductance screen default, using the Java-calculated Lmin of 27.397260273972603 µH as the selected inductor, the same original Java runtime probe returns 544.0091414176289% at 0% load. Flutter now exposes this source field and shows it in the Buck results; regression expectations use those actual Java runtime values rather than values generated by BuckEngine.


## 2026-11-11: floating-point parity and Buck diode orientation

The original inputs used for this check were restored from the user's Library
and verified before editing: `PSD5.jar` SHA-256
`a034c9fe92467342b2d24e2ceb1f734d8ab3227d6acda29ce59570a20a9a925f`;
`PSD5_java.zip` SHA-256
`1aa7e32095315684f44746404a4ed06eed9c61b04ee1e82d47c27577e8adbacf`.
The extracted `Buck.java`, the JAR class, and `javap -p -c` bytecode were
checked together.

Two source-order differences were found in the Flutter engine:

1. `Buck.general()` publishes `iripple = iind_max - iind_min`, after
   `singleValues()` has formed the two current endpoints. It does not reuse
   the earlier `iripple_buck` value. A two-pass OpenJDK 21 execution of the
   original JAR with a CCM point
   (`Vin=809.4736305932962 V`, `Vo=330.114238451388 V`,
   `Iout=92.48939803523659 A`, `fs=831605.2019290418 Hz`,
   `Vf=1.7138706798677177 V`, `L=297.41331803770024 µH`)
   returned `iripple_buck=0.7928217453261514 A`, but the displayed
   `iripple=0.7928217453261652 A` and
   `iripplepercent=0.8572028385611463%`. Flutter now derives the displayed
   excursion from `peak - minimum`, leaving the design-ripple value separate.

2. `Buck.onofftimes()` stores the raw DCM result
   `tzero_dccm_buck = 1/fs - ton_dccm_buck - toff_dccm_buck`. The bytecode
   contains no clamp of this value. `checktontoff()` checks `toff < 0` and the literal source condition `dFSwitch < ton`; it does not clamp or reject the zero-current interval. A two-pass execution of the original `Buck.calculate()` with
   `Vin=318.08966531879963 V`, `Vo=98.24616678566447 V`,
   `Iout=651.0248847976459 A`, `fs=2524.911090771719 Hz`,
   `Vf=1.7531008550235228 V`, and
   `L=20.90741011014667 µH` was classified DCM and returned
   `tzero=-1.0842021724855044e-19 s`. Flutter previously clamped that
   representable negative roundoff to zero. It now preserves the raw result.
   This fixture was selected only after executing the original class and
   confirming that Java itself classifies it DCM.

The input- and output-capacitor RMS calculations were also rewritten to retain
the original `actualValues()` current offsets, subtraction order, separate
ON/OFF integrals, and direct square-root operation. The earlier simplified
algebraic forms and non-source `max(0, squaredRms)` clamps have been removed.
Fixed CCM/DCM Java runtime values remain covered by the existing oracle tests;
the new negative-idle fixture additionally checks both capacitor RMS results.

The original JAR image
`PSD5_java/resources/images/fullView/nonsyncbuck_colored.png` was inspected
for the power-stage diode orientation. Its cathode bar is connected to the
switch node and its anode returns to ground. The Flutter schematic had these
ends reversed; the symbol is now oriented with its cathode bar above the
triangle and its anode below. A geometry regression test protects that
orientation. This is a visual comparison against the original embedded
schematic resource, not an inference from the calculation equations.

The new fixed numerical values above are from actual execution of the
original `Buck` class in `PSD5.jar` under OpenJDK 21 headless mode, with
two `calculate()` calls after setting the inputs. They are not generated by
the Flutter engine. The diode orientation is from the original image resource.


## 2026-11-11: Buck schematic topology and responsive fit

The original image resource
`PSD5_java/resources/images/fullView/nonsyncbuck_colored.png` (586 × 284)
was inspected directly from the recovered `PSD5_java.zip`. It shows input
capacitor Ci across the input rails before Q1, D1 returning from the Q1/L1
switch node to the return rail with its cathode at the switch node, L1 in
series after that node, and Co across the output rails. The positive and
return terminals at each end are separate terminals; the image does not join
the two rails with vertical end wires.

The previous Flutter drawing omitted Ci, placed the D1 branch below Q1 rather
than at the switch node, and drew vertical wires between the input and return
rails at both outer ends. These visual topology errors are corrected. The
drawing now includes Ci, connects D1 at the Q1/L1 node, and leaves the four
rail terminals electrically separate. Its fixed drawing canvas is fitted with
`BoxFit.contain` so wide layouts do not enlarge a 190 px-high drawing until
its lower half is clipped, while narrow layouts scale it down proportionally.

The schematic regression now checks the component order, diode polarity and
switch-node connection, plus narrow/wide fit behavior. This is a visual
comparison against the original embedded schematic resource, not a
calculation change or a claim of pixel-identical rendering.


## 2026-11-11: original checktontoff low-frequency warning

The extracted `Buck.java` and `javap -p -c` bytecode both confirm that
`checktontoff()` first flags a negative OFF time, then compares
`dFSwitch < ton` directly. `dFSwitch` is stored in hertz while `ton` is
stored in seconds; this is a dimensionally inconsistent check in the original
program, but it is observable UI behavior and is preserved as a warning rather
than used to reject the calculation.

This was verified by executing the original `Buck` class from
`PSD5.jar` under OpenJDK 21 headless mode. With
`Vin=18 V`, `Vo=12 V`, `Iout=5 A`, `fs=0.001 Hz`,
`Vf=0.5 V`, and `L=33 µH`, Java returned
`ton=0.19277490023901492 s`,
`toff=0.09253195211472717 s`, and
`duty=0.00019277490023901492`. The original Swing labels for ON time and
switching period were red; OFF time was not. Flutter now emits the same
source-condition warning, keeps the computed results visible, localizes the
warning in Arabic and English, and highlights the affected result values.
The regression values are fixed from this original-JAR runtime probe, not
from BuckEngine output.


## 2026-11-12: zero automatic Lmin at the 100% duty boundary

The original `Buck.calcMinInductance()` expression returns exactly zero when
`Vin(max) == Vo`. This is distinct from the selected inductor: the TI sheet
keeps `dLout` as a separate positive user input. An actual OpenJDK 21 run of
the original `Buck` class from `PSD5.jar`, with
`Vin(min)=Vin(max)=Vo=12 V`, `Iout=5 A`, `fs=200 kHz`, `Vf=0.5 V`,
and selected `L=33 µH`, returned:

- `Lmin=0 H`, selected `L=33 µH`, and CCM classification
- `duty=1`, `ton=5 µs`, `toff=0`, `tzero=1 ns`
- `Pout=60 W`, `Pin=60 W`, `Iin=5 A`
- MOSFET average/RMS current `5 A` / `4.999500074987503 A`
- diode average/RMS current `0 A` / `0 A`
- inductor average/RMS current `5 A` / `4.999500074987503 A`
- input- and output-capacitor RMS current `0 A`

Flutter's automatic-inductor mode previously substituted this zero `Lmin` as
the actual selected inductance. The subsequent `0 * Infinity` intermediate
made the CCM ripple non-finite and led to a misleading DCM-cycle error. The
engine now rejects only this automatic-zero case with a clear localized
message; supplying a positive custom inductance preserves the original Java
100%-duty CCM result. The numerical regression values above are fixed from
the original JAR runtime, not from Flutter output.

## 100% duty boundary graph runtime case

A fourth fixed graph fixture covers the exact 100% duty boundary using the
original `PSD5.jar` Buck class under OpenJDK 21. The input is
Vin(min)=Vin(max)=Vo=12 V, Iout=5 A, fs=200 kHz, Vf=0.5 V, and selected
L=33 µH. The original class returns CCM, ton=5 µs, toff=0, and its 1 ns
CCM zero-current epsilon. The five private device voltage/current point
methods were invoked reflectively after two calculation passes; their seven
per-cycle samples, twenty plotted time coordinates, and label metrics are
stored in the fixture.

At this exact boundary the source FET AC-current label evaluates
`sqrt(4.999500074987503² - 5²)`, which is NaN because the RMS value is slightly
below the average due to the 1 ns CCM normalization. The original Graph label
comparison does not switch units for NaN. The regression now preserves and
asserts that behavior. Also, because the fixed 1 ns graph transition offsets
are larger than the zero OFF interval, the original time array is
non-monotonic around each cycle boundary; the fixture records the exact order
rather than sorting it. This is an original-JAR runtime observation, not a
physical waveform recommendation.

The diode's displayed minimum-current metric is intentionally not the global
minimum of its plotted trace: `singleValues()` assigns `idiode_min` from the
inductor's CCM valley current, while `diodeCalcCCMCurrent()` still plots zero
current during the MOSFET ON interval. Therefore the 100% duty boundary has a
5 A diode minimum side label even though its trace contains zero-valued ON
samples. The fixture stores the original label-method result separately from
the waveform samples.


## 2026-11-13: output above minimum input range warning

The extracted `Buck.java` `checkOutputVolt()` (around lines 509-517) does
not abort calculation when `dVout > dVin_min`. It decrements both the
`outputvoltage` and `minimumInputVoltage` error-state counters. The
`userCalculate()` order (lines 464-475) runs `actualValues()`,
`singleValues()`, `general()`, output updates and graph time generation
before `runChecks()` marks the fields. The JAR bytecode for
`checkOutputVolt()` and `userCalculate()` confirms the same ordering.

An actual OpenJDK 21 headless execution of the original `Buck` class from
`PSD5.jar` was performed after setting Vin(min)=9 V, Vin(max)=18 V,
Vout=12 V, Iout=5 A, fs=200 kHz, ripple=30%, Vf=0.5 V, operating Vin=18 V,
and selected L=33 µH, followed by two `calculate()` calls. Java highlighted
both the output-voltage and minimum-input text fields while retaining the
calculated CCM result: duty=0.6756756756756758, ton=3.3783783783783788 µs,
toff=1.6216216216216216 µs, Pout=60 W, Pin=60.810810810810814 W,
MOSFET RMS=4.112147191587798 A, diode RMS=2.8489791456126947 A,
input-capacitor RMS=2.344908588716427 A, and output-capacitor RMS=
0.17731887874374277 A.

Flutter previously returned an empty result immediately for
`Vout > Vin(min)`, even when the selected operating input voltage was
sufficient. The engine now preserves the calculation and reports a
source-derived warning; the screen highlights both corresponding fields and
keeps the valid operating-point results visible in English and Arabic. Fixed
expected values in the regression test are from the actual Java runtime
probe above, not from BuckEngine. When the selected operating input itself
cannot support the requested output (duty above 100%), Flutter continues to
reject that operating point rather than displaying the NaN/negative-time
results that the original Swing sheet can expose while flagging its fields.


## 2026-11-13: negative calculated Lmin is not the zero-Lmin boundary

The extracted `Buck.java` `calcMinInductance()` (source lines 848-855)
computes

`Lmin = (1/fs) * (Vin(max)-Vo) * ((Vo+Vf)/(Vin(max)+Vf)) * (1/(Iout*ripple))`.

This is exactly zero when `Vin(max) == Vo`, but it is negative when
`Vin(max) < Vo`. The source's `checkDutyCycle()` flags duty above 1, and
`checktontoff()` flags negative OFF time and the selected-inductance field.
The same branches are present in `PSD5.jar` bytecode. Source and JAR inputs
were rechecked for this audit (SHA-256: `PSD5_java.zip`
`1aa7e32095315684f44746404a4ed06eed9c61b04ee1e82d47c27577e8adbacf`;
`PSD5.jar`
`a034c9fe92467342b2d24e2ceb1f734d8ab3227d6acda29ce59570a20a9a925f`).

An actual OpenJDK 21 headless execution of the original `Buck` class from
`PSD5.jar` used Vin(min)=9 V, Vin(max)=18 V, Vo=19 V, Iout=5 A,
fs=200 kHz, ripple=30%, Vf=0.5 V, operating Vin=18 V, and selected
L=33 µH, then called `calculate()` twice. Java returned:

- `Lmin = -3.5135135135135134 µH`
- `duty = 1.0540540540540542`
- `ton = 5.2702702702702705 µs`
- `toff = -0.27027027027027013 µs`
- `CCM = 1`

The original Swing UI highlighted Vin(min), Vout, selected inductance,
duty-cycle output, and OFF-time output. This was confirmed by reading the
actual component backgrounds after the runtime calculation.

Flutter previously treated every `Lmin <= 0` as the exact zero-Lmin
100%-duty boundary and returned the zero-Lmin message before checking the
selected operating-point duty. For a negative Lmin, that message was false:
the source equations imply `Vin(op) <= Vin(max) < Vo`, hence duty exceeds
100%. The engine now checks selected-point duty before the automatic-Lmin
special case, so negative Lmin reaches the over-duty guard. Exact zero Lmin
at exactly 100% duty still receives the dedicated automatic-inductance
message. The early over-duty path also carries the source's negative-OFF-time
warning so Flutter highlights the selected-inductance control and OFF-time
result as the Java UI does. The regression covers both negative Lmin and
zero Lmin with an under-voltage selected operating point. Flutter intentionally
does not display the original Java negative-OFF-time/invalid waveform numbers;
the duty error is a safety guard, not a literal TI error message.


## 2026-11-13: non-finite automatic minimum inductance

The original `getUserValues()` parses ripple as a percentage and divides it
by 100. `calcMinInductance()` then multiplies that fraction by rated output
current and takes its reciprocal in the Lmin expression. With an extremely
small but still positive ripple input, the intermediate remains nonzero while
its reciprocal overflows to positive infinity. This is distinct from the
exact zero Lmin at `Vin(max) == Vo`.

An actual OpenJDK 21 headless execution of the original `Buck` class from
`PSD5.jar` used Vin(min)=18 V, Vin(max)=36 V, Vo=12 V, Iout=5 A,
fs=200 kHz, ripple input=1e-320 percent, Vf=0.5 V, operating Vin=18 V,
and selected L=33 µH, followed by two `calculate()` calls. Java returned
`dcurrent_ripple=9.9E-323`, `iripple_buck_preset=4.94E-322`,
`Lmin=Infinity`, while still calculating a valid selected-inductor
operating point: duty=0.6756756756756758, ton=3.3783783783783788 µs,
toff=1.6216216216216216 µs, Pout=60 W, and Pin=60.810810810810814 W.
The source and `javap -p -c` bytecode both confirm this operation order.

Flutter's automatic mode previously grouped non-finite Lmin with exact zero
and returned the zero-boundary message. It now reports a separate localized
non-finite automatic-inductance error rather than mislabeling the condition.
A finite custom 33 µH selection still calculates the same source operating
point; its reported Lmin remains positive infinity and the source ripple-limit
warning is preserved. The non-finite error is a Flutter safety message, not
a literal TI error string.


## 2026-11-13: GraphPanel x-axis extrema

The original `GraphPanel.getMinimumX()` and `getMaximumX()` scan every point in the array passed to the panel. The original `Graph` constructor and `setPoints()` first copy only the first `length - 1` samples, so Buck displays the first 20 of its 21 generated time samples. The Flutter painter previously used only `points.first` and `points.last` as the x-axis bounds.

An actual OpenJDK 21 runtime probe of the original `PSD5.jar` was run headlessly with Vin(min)=Vin(max)=10000 V, Vo=0.001 V, Iout=5 A, fs=10 MHz, Vf=0.5 V, ripple target=30%, and selected L=2200 µH. The original `Buck` class returned ton=5.009749512524374e-12 s, toff=9.999499025048747e-8 s, and t3=1 ns. Its 1 ns graph transition offset therefore creates a plotted sample at -0.0009949902504874757 µs, even though the first plotted sample is 0 µs. Instantiating the original `GraphPanel` with the first 20 runtime samples returned minX=-0.0009949902504874757 µs and maxX=0.30400000000000005 µs. The former Flutter first/last range started at 0 µs and clipped that negative transition.

The painter now obtains both x-axis bounds by scanning all retained points, matching the original GraphPanel algorithm. A regression test covers this sub-nanosecond ON-time case using the actual-JAR runtime extrema. No Buck calculation equation or generated waveform sample was changed.


## 2026-11-14: exact GraphPanel x-coordinate transform

A follow-up comparison of `GraphPanel.paintComponent()` found that matching
only `getMinimumX()` and `getMaximumX()` is insufficient. The original
Java computes `mappingX = X / abs(maxX - minX)`, then maps each point as
`65 + point.x * mappingX`. It does **not** subtract `minX` from each point
before mapping. Its tick text is computed as
`maxX * (point.x * mappingX / X)`. The Flutter painter now preserves this
same zero-origin transform while using the all-points range for the scale;
it does not shift the negative sample to the left plot boundary.

This was checked against an actual OpenJDK 21 execution of the original
`PSD5.jar` and its `GraphPanel` class. With the sub-nanosecond ON-time
fixture above and a 600 px panel (`X = width - 130 = 470`), Java returned
`mappingX=1541.0089182579572 px/µs`, a screen offset of
`-1.53328884958092 px` for the negative sample, and
`468.4667111504191 px` for the final retained sample. Its tick-label
numeric inputs at indexes 6 and 18 were
`0.09967376832987639` and `0.3010147803562267`, respectively.
The regression test asserts these Java runtime values independently of
BuckEngine. No waveform sample or calculation equation changed.


## 2026-11-13: non-finite minimum-inductance label formatting

The original `Buck.updateValues()` uses `new DecimalFormat("#0.00").format(lmin_buck * 1e6)`. The extracted source and `javap -p -c` bytecode confirm the formatter and conversion order. A direct OpenJDK 21 headless run of the original `Buck` class from `PSD5.jar` with Vin(min)=18 V, Vin(max)=36 V, Vo=12 V, Iout=5 A, fs=200 kHz, ripple input=1e-320 percent, Vf=0.5 V, and selected L=33 µH returned Lmin=+Infinity; the actual Swing label contained Unicode U+221E (∞). Flutter previously used `double.toStringAsFixed(2)`, which renders the word `Infinity` rather than the original symbol. The Buck screen now formats positive and negative infinite inductance labels with the TI infinity symbol while retaining the two-decimal format for finite values. A second original-JAR runtime probe at Vin(min)=Vin(max)=Vo=12 V with the same tiny ripple returned Lmin=NaN and the source label `NaN`; Flutter's normal NaN formatting remains unchanged. No calculation equation was changed.
