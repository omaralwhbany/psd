# Buck non-finite inductance runtime audit

Scope: positive custom inductance values near the binary64 underflow/overflow
range. No calculation formula is changed by this audit.

## Source and bytecode evidence

The original files used for this run were verified by SHA-256:

- `PSD5.jar`: `a034c9fe92467342b2d24e2ceb1f734d8ab3227d6acda29ce59570a20a9a925f`
- `PSD5_java.zip`: `1aa7e32095315684f44746404a4ed06eed9c61b04ee1e82d47c27577e8adbacf`

In `PSD5_java/com/ti/switchingpowersupplydesign/sheets/Buck.java`,
`getUserModifiedValues()` parses the entered inductance in µH and divides it
by 1,000,000. `checkInductance()` accepts any resulting value satisfying
`dLout > 0.0 && dLout <= 0.0022`; it imposes no positive lower bound.

The corresponding `PSD5.jar` bytecode confirms the same two comparisons.
`inductorGetLabelsValuesCurrent()` formats minimum, maximum, RMS, average,
and AC current labels with `DecimalFormat("#0.00####")`. `Graph.java` then
parses those label strings with `Double.parseDouble` before selecting units.

## Direct original-Java runtime probe

The original `com.ti.switchingpowersupplydesign.sheets.Buck` class was
instantiated and executed from `PSD5.jar` under OpenJDK 21 with:

| Input | Value |
|---|---:|
| Vin min / max | 18 V / 36 V |
| Vout | 12 V |
| Iout | 5 A |
| Switching frequency | 200 kHz |
| Ripple target | 30% |
| Diode forward drop | 0.5 V |
| Custom inductance | 1e-310 µH |

The source converts the custom inductance to 1e-316 H. The actual Java runtime
reported DCM, an infinite inductor peak and RMS current, and NaN input- and
output-capacitor RMS currents. The inductance field remained unhighlighted:
1e-316 H is positive and below the source's 0.0022 H maximum.

The original inductor label method returned the infinity symbol for its
infinite values and `NaN` for the non-number value. A separate Java check
confirmed that `Double.parseDouble("∞")` throws `NumberFormatException`.
Since the original `Graph` constructor parses every formatted label this way,
the original graph cannot be created for this non-finite case even though
`Buck` itself completes its calculation.

At 1e-320 µH, division by 1,000,000 underflows the selected inductance to
zero; the original `checkInductance()` then highlights the field.

## Flutter handling

The Flutter engine keeps the same finite-positive acceptance rule and
non-finite calculation results; no Buck equation is changed. Result labels
render infinity as `∞` and NaN as `NaN`, matching the original
`DecimalFormat` special-value strings. Device and synchronized waveform
panels are hidden only when their plotted samples or metrics are non-finite,
because the original Java graph path cannot parse its infinity label. Other
calculated result rows remain visible.

Finite-number rounding is intentionally unchanged here. Full finite-value
`DecimalFormat` parity remains a separate open audit item; this change does
not claim to resolve PR #13's large-finite-number mismatch.
