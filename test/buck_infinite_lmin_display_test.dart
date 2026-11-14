import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_screen.dart';

void main() {
  testWidgets(
    'Buck displays the original TI infinity symbol for non-finite Lmin',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        supportedLocales: [Locale('en'), Locale('ar')],
        home: Scaffold(body: BuckScreen()),
      ));
      await tester.pumpAndSettle();

      final rippleField = find.byType(TextField).at(6);
      await tester.ensureVisible(rippleField);
      await tester.enterText(rippleField, '1e-320');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Automatic inductance is not finite for the requested ripple target; choose a finite custom inductance.',
        ),
        findsOneWidget,
      );

      final customToggle = find.text('Use custom inductor value');
      await tester.ensureVisible(customToggle);
      await tester.tap(customToggle);
      await tester.pumpAndSettle();

      final inductanceField = find.byType(TextField).last;
      await tester.ensureVisible(inductanceField);
      await tester.enterText(inductanceField, '33');
      await tester.pumpAndSettle();

      expect(find.text('∞ µH'), findsOneWidget);
      expect(find.text('60.00 W'), findsOneWidget);
      expect(find.text('Infinity µH'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
