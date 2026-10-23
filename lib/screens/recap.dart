import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../util.dart';
import '../widgets.dart';

/// Texte du récap pour WhatsApp (gras = *texte*).
/// Seules les danses cochées « faites » sont reprises, sauf si aucune ne l'est.
/// Parties fixes regroupées, puis le corpus dans l'ordre réel du cours.
String genererRecap(Cours c) {
  final faites = c.deroule.where((e) => e.fait).toList();
  final source = faites.isEmpty ? c.deroule : faites;
  String nom(Entree e) => e.danse != null
      ? '*${e.danse}*'
      : (e.artiste == null ? e.titre : '${e.titre} (${e.artiste})');
  final b = StringBuffer()
    ..writeln('Bonjour ! Vous étiez ${c.presents} danseuses et danseurs '
        'pour ce cours du ${dateFr(c.jour)}.')
    ..writeln('Voici le récap :');
  for (final bloc in [Bloc.echauffement, Bloc.mej, Bloc.mystere]) {
    final noms = <String>[];
    for (final e in source.where((e) => e.section.bloc == bloc)) {
      final n = nom(e);
      if (!noms.contains(n)) noms.add(n);
    }
    if (noms.isNotEmpty) b.writeln('- ${bloc.label} : ${noms.join(', ')}');
  }
  for (final e in source.where((e) => e.section.bloc == Bloc.corpus)) {
    final type = e.section == Section.nouvelles ? 'nouveau' : 'révision';
    b.writeln('- ${nom(e)} ($type)');
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
