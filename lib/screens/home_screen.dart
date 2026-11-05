import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../navigation/app_drawer.dart';
import '../topologies/buck/buck_screen.dart';
import '../topologies/boost/boost_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.locale, required this.onLocaleChanged});
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _topology = 'buck';

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.locale);
    final title = _topology == 'buck' ? strings.buckConverter : strings.boostConverter;
    return Scaffold(
      drawer: AppDrawer(
        strings: strings,
        selectedTopology: _topology,
        onTopologySelected: (value) => setState(() => _topology = value),
        onLanguageChanged: () {
          Navigator.pop(context);
          widget.onLocaleChanged(Locale(widget.locale.languageCode == 'en' ? 'ar' : 'en'));
        },
      ),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(strings.appTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(strings.subtitle, style: Theme.of(context).textTheme.labelSmall),
        ]),
        actions: [
          IconButton(tooltip: strings.language, onPressed: () => widget.onLocaleChanged(Locale(widget.locale.languageCode == 'en' ? 'ar' : 'en')), icon: const Icon(Icons.language)),
          const SizedBox(width: 8),
        ],
      ),
      body: _topology == 'buck' ? const BuckScreen() : _topology == 'boost' ? const BoostScreen() : Center(child: Text(title)),
    );
  }
}