import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'player.dart';
import 'util.dart';

/// Barre de progression déplaçable + temps écoulé / total (ou restant).
class Progression extends StatelessWidget {
  final bool restant;
  final double taillePolice;
  const Progression({super.key, this.restant = false, this.taillePolice = 18});

  @override
  Widget build(BuildContext context) {
    final l = Lecteur.I;
    return StreamBuilder<Duration>(
      stream: l.position,
      builder: (context, snap) {
        final total = l.duree;
        var pos = snap.data ?? Duration.zero;
        if (pos > total) pos = total;
        final max = total.inMilliseconds <= 0 ? 1.0 : total.inMilliseconds.toDouble();
        final style = TextStyle(
          fontSize: taillePolice,
          fontWeight: FontWeight.bold,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: pos.inMilliseconds.toDouble().clamp(0.0, max),
              max: max,
              onChanged: l.chemin == null
                  ? null
                  : (v) => l.aller(Duration(milliseconds: v.round())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(duree(pos), style: style),
                  Text(
                    restant ? '-${duree(total - pos)}' : duree(total),
                    style: style.copyWith(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Petit lecteur en bas des listes : titre, lecture/pause, retour au début.
class MiniLecteur extends StatelessWidget {
  const MiniLecteur({super.key});

  @override
  Widget build(BuildContext context) {
    final l = Lecteur.I;
    return ListenableBuilder(
      listenable: l,
      builder: (context, _) {
        if (l.chemin == null) return const SizedBox.shrink();
        return Material(
          elevation: 8,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Retour au début',
                        icon: const Icon(Icons.skip_previous),
                        onPressed: l.auDebut,
                      ),
                      IconButton.filled(
                        tooltip: l.enLecture ? 'Pause' : 'Lecture',
                        iconSize: 32,
                        icon: Icon(l.enLecture ? Icons.pause : Icons.play_arrow),
                        onPressed: l.basculer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.nom,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(l.detail, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Progression(taillePolice: 14),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<bool> confirmer(BuildContext context, String question, {String oui = 'Oui'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(question),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(oui)),
      ],
    ),
  );
  return r ?? false;
}

void message(BuildContext context, String texte) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
}
