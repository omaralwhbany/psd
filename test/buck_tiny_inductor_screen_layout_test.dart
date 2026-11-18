import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/localization/app_strings.dart';
import 'package:psd/topologies/buck/buck_screen.dart';

void main() {
  testWidgets(
    'Buck tiny-inductor DCM results remain visible on a narrow Arabic screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const locale = Locale('ar');
      await tester.pumpWidget(
        const MaterialApp(
          locale: locale,
          supportedLocales: [Locale('en'), Locale('ar')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: BuckScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final strings = AppStrings(locale);
      expect(
        Directionality.of(tester.element(find.text(strings.buckConverter))),
        TextDirection.rtl,
      );

      final customInductor = find.byType(SwitchListTile);
      await tester.ensureVisible(customInductor);
      await tester.pumpAndSettle();
      await tester.tap(customInductor);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(customInductor).value, isTrue);

      final inductanceField = find.byType(TextField).last;
      await tester.ensureVisible(inductanceField);
      await tester.pumpAndSettle();
      await tester.enterText(inductanceField, '1e-90');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(inductanceField).controller!.text,
        '1e-90',
      );

      final rippleWarning = find.text(
        strings.localizeBuckWarning(
          'Actual inductor ripple exceeds the requested ripple target.',
        ),
      );
      await tester.ensureVisible(rippleWarning);
      await tester.pumpAndSettle();

      expect(find.text(strings.outputPower), findsOneWidget);
      expect(find.text(strings.inputPower), findsOneWidget);
      expect(rippleWarning, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
