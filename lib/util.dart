import 'dart:math';

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i',
  'ñ': 'n',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'õ': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae',
  '’': "'",
};

/// Minuscules sans accents, pour comparer et rechercher.
String plier(String s) {
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    b.write(_accents[c] ?? c);
  }
  return b.toString();
}

/// Nom de fichier sûr à partir d'un nom de danse.
String slug(String s) {
  final p = plier(s).replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return p.replaceAll(RegExp(r'^-+|-+$'), '');
}

final _rnd = Random();

String nouvelId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 20).toRadixString(36)}';

String deux(int n) => n.toString().padLeft(2, '0');

/// 2026-10-23
String dateIso(DateTime d) => '${d.year}-${deux(d.month)}-${deux(d.day)}';

/// 23/10/2026
String dateFr(DateTime d) => '${deux(d.day)}/${deux(d.month)}/${d.year}';

const _jours = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

/// ven. 23/10/2026
String dateFrCourte(DateTime d) => '${_jours[d.weekday - 1]} ${dateFr(d)}';

String saisonDe(DateTime d) =>
    d.month >= 8 ? '${d.year}-${d.year + 1}' : '${d.year - 1}-${d.year}';

/// 3:42
String duree(Duration? d) {
  if (d == null) return '–:––';
  final s = d.inSeconds;
  return '${s ~/ 60}:${deux(s % 60)}';
}
