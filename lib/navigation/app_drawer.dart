import 'package:flutter/material.dart';
import '../localization/app_strings.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.strings, required this.onLanguageChanged});
  final AppStrings strings;
  final VoidCallback onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final stages = [strings.buckConverter, 'Boost Converter', 'Inverting Buck-Boost', 'SEPIC', 'Zeta', 'Ćuk', 'Flyback', 'Forward Converter', 'LLC Resonant'];
    final tools = ['MOSFET Losses', 'Loop Compensation', 'Filter Designer', 'Bulk Capacitor', 'Current Sharing', 'Snubber Designer', 'Load Step', 'Resistor Divider'];
    return Drawer(child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.appTitle, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)), Text(strings.subtitle)])),
      const Divider(height: 1),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
        _section(strings.powerStages),
        for (var i = 0; i < stages.length; i++) ListTile(leading: Icon(i == 0 ? Icons.check_circle : Icons.memory, color: i == 0 ? Theme.of(context).colorScheme.primary : null), title: Text(stages[i]), subtitle: i == 0 ? null : Text(strings.comingSoon), selected: i == 0, onTap: () => Navigator.pop(context)),
        _section(strings.designTools),
        for (final tool in tools) ListTile(leading: const Icon(Icons.calculate_outlined), title: Text(tool), subtitle: Text(strings.comingSoon), onTap: () => Navigator.pop(context)),
      ])),
      const Divider(height: 1),
      ListTile(leading: const Icon(Icons.language), title: Text(strings.language), onTap: onLanguageChanged),
    ])));
  }

  Widget _section(String title) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 6), child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)));
}
