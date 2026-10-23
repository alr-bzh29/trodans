// Affichage Markdown simple, sans dépendance externe :
// # titres, - listes à puces, 1. listes numérotées, > citations,
// **gras**, *italique* ou _italique_, `code`.

import 'package:flutter/material.dart';

import 'models.dart';

class MarkdownSimple extends StatelessWidget {
  final String texte;
  final double taille;
  const MarkdownSimple(this.texte, {super.key, this.taille = 16});

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.copyWith(fontSize: taille, height: 1.4);
    final lignes = texte.replaceAll('\r', '').split('\n');
    final enfants = <Widget>[];
    for (final brute in lignes) {
      final l = brute.trimRight();
      if (l.trim().isEmpty) {
        enfants.add(SizedBox(height: taille * 0.5));
        continue;
      }
      final titre = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(l);
      if (titre != null) {
        final niveau = titre.group(1)!.length;
        final f = taille * (niveau == 1 ? 1.4 : niveau == 2 ? 1.25 : 1.1);
        enfants.add(Padding(
          padding: EdgeInsets.only(top: taille * 0.3),
          child: Text.rich(
            TextSpan(children: _inline(titre.group(2)!, base)),
            style: base.copyWith(fontSize: f, fontWeight: FontWeight.bold),
          ),
        ));
        continue;
      }
      final puce = RegExp(r'^(\s*)[-*+]\s+(.*)$').firstMatch(l);
      final num = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$').firstMatch(l);
      if (puce != null || num != null) {
        final retrait = (puce ?? num)!.group(1)!.length;
        final marque = puce != null ? '•' : '${num!.group(2)}.';
        final contenu = puce != null ? puce.group(2)! : num!.group(3)!;
        enfants.add(Padding(
          padding: EdgeInsets.only(left: 4.0 + retrait * 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: taille * 1.4, child: Text(marque, style: base)),
              Expanded(child: Text.rich(TextSpan(children: _inline(contenu, base)), style: base)),
            ],
          ),
        ));
        continue;
      }
      if (l.startsWith('>')) {
        enfants.add(Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Theme.of(context).dividerColor, width: 3)),
          ),
          child: Text.rich(
            TextSpan(children: _inline(l.substring(1).trimLeft(), base)),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        ));
        continue;
      }
      enfants.add(Text.rich(TextSpan(children: _inline(l, base)), style: base));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: enfants);
  }

  static final _motif = RegExp(r'\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|_(.+?)_|`(.+?)`');

  List<InlineSpan> _inline(String s, TextStyle base) {
    final res = <InlineSpan>[];
    var i = 0;
    for (final m in _motif.allMatches(s)) {
      if (m.start > i) res.add(TextSpan(text: s.substring(i, m.start)));
      if (m.group(1) != null || m.group(2) != null) {
        res.add(TextSpan(
            text: m.group(1) ?? m.group(2),
            style: const TextStyle(fontWeight: FontWeight.bold)));
      } else if (m.group(3) != null || m.group(4) != null) {
        res.add(TextSpan(
            text: m.group(3) ?? m.group(4),
            style: const TextStyle(fontStyle: FontStyle.italic)));
      } else {
        res.add(TextSpan(
            text: m.group(5),
            style: const TextStyle(fontFamily: 'monospace')));
      }
      i = m.end;
    }
    if (i < s.length) res.add(TextSpan(text: s.substring(i)));
    return res;
  }
}

/// Couleur propre à chaque section (lisible en thème clair et sombre).
Color couleurSection(Section s, Brightness b) {
  final clair = b == Brightness.light;
  return switch (s) {
    Section.echauffement => clair ? const Color(0xFF00796B) : const Color(0xFF4DB6AC),
    Section.mej => clair ? const Color(0xFF1F4E8C) : const Color(0xFF90B8F0),
    Section.mystere => clair ? const Color(0xFFB45309) : const Color(0xFFF2B66D),
    Section.revisions => clair ? const Color(0xFF6A1B9A) : const Color(0xFFCE93D8),
    Section.nouvelles => clair ? const Color(0xFF2E7D32) : const Color(0xFF81C784),
    Section.extras => clair ? const Color(0xFF546E7A) : const Color(0xFFB0BEC5),
  };
}

/// Fenêtre d'édition d'un texte Markdown. Renvoie null si annulé.
Future<String?> editerMarkdown(BuildContext context, String titre, String initial) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titre),
      content: SizedBox(
        width: 600,
        child: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 6,
          maxLines: 16,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            helperText: '**gras**  *italique*  # titre  - liste',
            helperMaxLines: 2,
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Enregistrer')),
      ],
    ),
  );
}
