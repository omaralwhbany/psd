import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_screen.dart';

Future<void> _pumpNarrowBuck(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(320, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: BuckScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Buck narrow Arabic layout remains RTL without overflow',
      (tester) async {
    await _pumpNarrowBuck(tester, const Locale('ar'));

    expect(
      Directionality.of(tester.element(find.text('محول خافض Buck'))),
      TextDirection.rtl,
    );
    await tester.scrollUntilVisible(
      find.text('قدرة الخرج'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('قدرة الخرج'), findsOneWidget);
    expect(find.text('قدرة الدخل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Buck narrow English layout remains LTR and renders device graphs',
      (tester) async {
    await _pumpNarrowBuck(tester, const Locale('en'));

    expect(
      Directionality.of(tester.element(find.text('Buck Converter'))),
      TextDirection.ltr,
    );
    await tester.scrollUntilVisible(
      find.text('Output power'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Output power'), findsOneWidget);
    expect(find.text('Input power'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Buck device waveforms (PSD5 source model)'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Buck device waveforms (PSD5 source model)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
