import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_theme.dart';
import '../screens/home_screen.dart';

class PsdApp extends StatefulWidget {
  const PsdApp({super.key});
  @override
  State<PsdApp> createState() => _PsdAppState();
}

class _PsdAppState extends State<PsdApp> {
  Locale _locale = const Locale('en');
  void _changeLocale(Locale locale) => setState(() => _locale = locale);

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'PSD',
    theme: AppTheme.light,
    locale: _locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: HomeScreen(locale: _locale, onLocaleChanged: _changeLocale),
  );
}
