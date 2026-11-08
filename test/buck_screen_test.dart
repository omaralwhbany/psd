import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_screen.dart';

void main() {
  testWidgets('Buck results fit a narrow Arabic screen without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: [Locale('ar'), Locale('en')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: BuckScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('قدرة الخرج'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('قدرة الخرج'), findsOneWidget);
    expect(find.text('قدرة الدخل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Buck screen shows the TI ripple-limit warning without hiding results',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('en'),
      supportedLocales: [Locale('en'), Locale('ar')],
      home: Scaffold(body: BuckScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use custom inductor value'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '5');
    await tester.pumpAndSettle();

    expect(find.text('$warning'), findsOneWidget);
    expect(find.text('Operating point'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
