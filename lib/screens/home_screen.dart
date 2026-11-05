import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../navigation/app_drawer.dart';
import '../topologies/buck/buck_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.locale, required this.onLocaleChanged});
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(locale);
    return Scaffold(
      drawer: AppDrawer(strings: strings, onLanguageChanged: () {
        Navigator.pop(context);
        onLocaleChanged(Locale(locale.languageCode == 'en' ? 'ar' : 'en'));
      }),
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.appTitle, style: const TextStyle(fontWeight: FontWeight.bold)), Text(strings.subtitle, style: Theme.of(context).textTheme.labelSmall)]), actions: [IconButton(tooltip: strings.language, onPressed: () => onLocaleChanged(Locale(locale.languageCode == 'en' ? 'ar' : 'en')), icon: const Icon(Icons.language)), const SizedBox(width: 8)]),
      body: const BuckScreen(),
    );
  }
}
