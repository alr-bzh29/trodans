import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../util.dart';
import '../widgets.dart';

/// Texte du récap pour WhatsApp (gras = *texte*).
/// Seules les danses cochées « faites » sont reprises, sauf si aucune ne l'est.
String genererRecap(Cours c) {
  final faites = c.entrees.where((e) => e.fait).toList();
  final source = faites.isEmpty ? c.entrees : faites;
  final b = StringBuffer()
    ..writeln('Bonjour ! Vous étiez ${c.presents} danseuses et danseurs '
        'pour ce cours du ${dateFr(c.jour)}.')
    ..writeln('Voici le récap :');
  for (final s in Section.values) {
    final noms = <String>[];
    for (final e in source.where((e) => e.section == s)) {
      final n = e.danse != null
          ? '*${e.danse}*'
          : (e.artiste == null ? e.titre : '${e.titre} (${e.artiste})');
      if (!noms.contains(n)) noms.add(n);
    }
    if (noms.isNotEmpty) b.writeln('- ${s.label} : ${noms.join(', ')}');
  }
  return b.toString().trimRight();
}

class RecapEcran extends StatelessWidget {
  final Cours cours;
  const RecapEcran({super.key, required this.cours});

  @override
  Widget build(BuildContext context) {
    final texte = genererRecap(cours);
    return Scaffold(
      appBar: AppBar(title: const Text('Récap WhatsApp')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(texte, style: const TextStyle(fontSize: 16, height: 1.5)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les *étoiles* deviennent du gras dans WhatsApp.',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.copy),
        label: const Text('Copier'),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: texte));
          if (context.mounted) message(context, 'Récap copié');
        },
      ),
    );
  }
}
