import 'package:flutter/material.dart';
import '../localization/app_strings.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.strings, required this.onLanguageChanged, required this.onTopologySelected, required this.selectedTopology});
  final AppStrings strings;
  final VoidCallback onLanguageChanged;
  final ValueChanged<String> onTopologySelected;
  final String selectedTopology;

  @override
  Widget build(BuildContext context) {
    final stages = [
      ('buck', strings.buckConverter),
      ('boost', strings.boostConverter),
      ('inverting', 'Inverting Buck-Boost'),
      ('sepic', 'SEPIC'), ('zeta', 'Zeta'), ('cuk', 'Ćuk'),
      ('sync_buck', 'Synchronous Buck'), ('series_cap_buck', 'Series Capacitor Buck'),
      ('flyback', 'Flyback'), ('qr_flyback', 'QR Flyback'), ('two_switch_flyback', 'Two-Switch Flyback'),
      ('forward', 'Single-Switch Forward'), ('two_switch_forward', 'Two-Switch Forward'),
      ('active_clamp_forward', 'Active-Clamp Forward'), ('half_bridge', 'Half Bridge'),
      ('full_bridge', 'Full Bridge'), ('push_pull', 'Push-Pull'),
      ('psfb', 'Phase-Shifted Full Bridge'), ('llc_half', 'LLC Half Bridge'),
      ('llc_full', 'LLC Full Bridge'), ('weinberg', 'Weinberg'),
    ];
    final tools = ['MOSFET Losses', 'Loop Compensation', 'Filter Designer', 'Bulk Capacitor', 'Current Sharing', 'Snubber Designer', 'Load Step', 'Resistor Divider'];
    return Drawer(child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(strings.appTitle, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(strings.subtitle),
      ])),
      const Divider(height: 1),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
        _section(strings.powerStages),
        for (final stage in stages)
          ListTile(
            leading: Icon(stage.$1 == 'buck' ? Icons.south : stage.$1 == 'boost' ? Icons.north : Icons.memory),
            title: Text(stage.$2),
            subtitle: stage.$1 == 'buck' || stage.$1 == 'boost' ? null : Text(strings.comingSoon),
            selected: selectedTopology == stage.$1,
            onTap: () { Navigator.pop(context); if (stage.$1 == 'buck' || stage.$1 == 'boost') onTopologySelected(stage.$1); },
          ),
        _section(strings.designTools),
        for (final tool in tools) ListTile(leading: const Icon(Icons.calculate_outlined), title: Text(tool), subtitle: Text(strings.comingSoon), onTap: () => Navigator.pop(context)),
      ])),
      const Divider(height: 1),
      ListTile(leading: const Icon(Icons.language), title: Text(strings.language), onTap: onLanguageChanged),
    ])));
  }

  Widget _section(String title) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 6), child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)));
}