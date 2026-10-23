import 'dart:async';

import 'package:flutter/material.dart';

import '../storage.dart';
import '../util.dart';

/// Bandeau du mode « en cours » : heure actuelle, puis minutes restantes
/// jusqu'à la fin du cours, ou dépassement (en couleur d'alerte).
class HorlogeCours extends StatefulWidget {
  const HorlogeCours({super.key});

  @override
  State<HorlogeCours> createState() => _HorlogeCoursState();
}

class _HorlogeCoursState extends State<HorlogeCours> {
  late Timer _minuteur;
  DateTime _maintenant = DateTime.now();

  @override
  void initState() {
    super.initState();
    _minuteur = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() => _maintenant = DateTime.now());
    });
  }

  @override
  void dispose() {
    _minuteur.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fin = Depot.I.reglages.finCoursMinutes;
    final n = _maintenant;
    final ecart = fin - (n.hour * 60 + n.minute); // > 0 : minutes restantes
    final cs = Theme.of(context).colorScheme;
    final depasse = ecart < 0;
    final bientot = !depasse && ecart <= 10;
    final couleur = depasse ? cs.error : (bientot ? const Color(0xFFF2B66D) : cs.onSurfaceVariant);
    final texte = depasse
        ? 'fin dépassée de ${_duree(-ecart)}'
        : ecart == 0
            ? 'fin du cours maintenant'
            : 'reste ${_duree(ecart)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('${deux(n.hour)}:${deux(n.minute)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(texte,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: couleur)),
          Text('  (fin ${fin ~/ 60}h${deux(fin % 60)})',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  String _duree(int minutes) =>
      minutes < 60 ? '$minutes min' : '${minutes ~/ 60} h ${deux(minutes % 60)}';
}
