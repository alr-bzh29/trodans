// Lecture des tags audio, sans dépendance externe :
// - MP3 : ID3v2 (2.2, 2.3, 2.4) puis ID3v1 en secours ; durée via TLEN,
//   l'en-tête Xing/Info (VBR) ou une estimation à débit constant.
// - OGG : commentaires Vorbis (ou OpusTags) ; durée via la dernière page.
// En cas d'erreur, renvoie ce qui a pu être lu (jamais d'exception).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class Tags {
  String? titre;
  String? artiste;
  String? album;
  String? genre;
  int? dureeMs;
}

Future<Tags> lireTags(File f) async {
  final t = Tags();
  RandomAccessFile? raf;
  try {
    raf = await f.open();
    final taille = await raf.length();
    final nom = f.path.toLowerCase();
    if (nom.endsWith('.mp3')) {
      await _mp3(raf, taille, t);
    } else if (nom.endsWith('.ogg') || nom.endsWith('.opus')) {
      await _ogg(raf, taille, t);
    }
  } catch (_) {
    // fichier illisible ou tag abîmé : on garde ce qu'on a
  } finally {
    await raf?.close();
  }
  t.titre = _propre(t.titre);
  t.artiste = _propre(t.artiste);
  t.album = _propre(t.album);
  t.genre = _genre(t.genre);
  return t;
}

String? _propre(String? s) {
  if (s == null) return null;
  final v = s.replaceAll('\u0000', '').trim();
  return v.isEmpty ? null : v;
}

/// « (17)Rock » → « Rock » ; « (17) » seul → null.
String? _genre(String? s) {
  var g = _propre(s);
  if (g == null) return null;
  g = g.replaceAll(RegExp(r'^\(\d+\)'), '').trim();
  if (RegExp(r'^\d+$').hasMatch(g)) return null;
  return g.isEmpty ? null : g;
}

Future<Uint8List> _lire(RandomAccessFile raf, int pos, int n) async {
  await raf.setPosition(pos);
  return raf.read(n);
}

// ---------------------------------------------------------------- MP3

Future<void> _mp3(RandomAccessFile raf, int taille, Tags t) async {
  var debutAudio = 0;
  final h = await _lire(raf, 0, 10);
  if (h.length == 10 && h[0] == 0x49 && h[1] == 0x44 && h[2] == 0x33) {
    final maj = h[3];
    final flags = h[5];
    final tailleTag = _synchsafe(h, 6);
    debutAudio = 10 + tailleTag + ((flags & 0x10) != 0 ? 10 : 0);
    var data = await _lire(raf, 10, tailleTag);
    if ((flags & 0x80) != 0 && maj < 4) data = _desynchroniser(data);
    _id3v2(data, maj, flags, t);
  }
  if (t.titre == null || t.artiste == null) {
    if (taille >= 128) {
      final v1 = await _lire(raf, taille - 128, 128);
      if (v1[0] == 0x54 && v1[1] == 0x41 && v1[2] == 0x47) {
        t.titre ??= latin1.decode(v1.sublist(3, 33));
        t.artiste ??= latin1.decode(v1.sublist(33, 63));
        t.album ??= latin1.decode(v1.sublist(63, 93));
      }
    }
  }
  if (t.dureeMs == null || t.dureeMs! <= 0) {
    t.dureeMs = await _dureeMp3(raf, taille, debutAudio);
  }
}

int _synchsafe(Uint8List b, int o) =>
    (b[o] & 0x7f) << 21 | (b[o + 1] & 0x7f) << 14 | (b[o + 2] & 0x7f) << 7 | (b[o + 3] & 0x7f);

int _be32(Uint8List b, int o) => b[o] << 24 | b[o + 1] << 16 | b[o + 2] << 8 | b[o + 3];

Uint8List _desynchroniser(Uint8List d) {
  final out = BytesBuilder();
  for (var i = 0; i < d.length; i++) {
    out.addByte(d[i]);
    if (d[i] == 0xFF && i + 1 < d.length && d[i + 1] == 0x00) i++;
  }
  return out.toBytes();
}

void _id3v2(Uint8List d, int maj, int flags, Tags t) {
  var p = 0;
  if ((flags & 0x40) != 0 && d.length >= 4) {
    // en-tête étendu
    p = maj >= 4 ? _synchsafe(d, 0) : _be32(d, 0) + 4;
  }
  final court = maj == 2;
  final tailleEntete = court ? 6 : 10;
  while (p + tailleEntete <= d.length) {
    final id = ascii.decode(d.sublist(p, p + (court ? 3 : 4)), allowInvalid: true);
    if (id.codeUnitAt(0) == 0) break;
    int n;
    if (court) {
      n = d[p + 3] << 16 | d[p + 4] << 8 | d[p + 5];
    } else if (maj >= 4) {
      n = _synchsafe(d, p + 4);
    } else {
      n = _be32(d, p + 4);
    }
    final debut = p + tailleEntete;
    if (n <= 0 || debut + n > d.length) break;
    final contenu = d.sublist(debut, debut + n);
    switch (id) {
      case 'TIT2' || 'TT2':
        t.titre = _texte(contenu);
      case 'TPE1' || 'TP1':
        t.artiste = _texte(contenu);
      case 'TALB' || 'TAL':
        t.album = _texte(contenu);
      case 'TCON' || 'TCO':
        t.genre = _texte(contenu);
      case 'TLEN' || 'TLE':
        t.dureeMs = int.tryParse(_texte(contenu)?.trim() ?? '');
    }
    p = debut + n;
  }
}

String? _texte(Uint8List c) {
  if (c.isEmpty) return null;
  final enc = c[0];
  final b = c.sublist(1);
  String s;
  switch (enc) {
    case 0:
      s = latin1.decode(b);
    case 1:
      s = _utf16(b, null);
    case 2:
      s = _utf16(b, false);
    default:
      s = utf8.decode(b, allowMalformed: true);
  }
  // ID3v2.4 : plusieurs valeurs séparées par un caractère nul → on garde la première.
  final i = s.indexOf('\u0000');
  if (i >= 0) s = s.substring(0, i);
  return s;
}

String _utf16(Uint8List b, bool? petitBoutiste) {
  var i = 0;
  var le = petitBoutiste ?? false;
  if (b.length >= 2 && petitBoutiste == null) {
    if (b[0] == 0xFF && b[1] == 0xFE) {
      le = true;
      i = 2;
    } else if (b[0] == 0xFE && b[1] == 0xFF) {
      le = false;
      i = 2;
    }
  }
  final unites = <int>[];
  for (; i + 1 < b.length; i += 2) {
    final u = le ? b[i] | b[i + 1] << 8 : b[i] << 8 | b[i + 1];
    if (u == 0) break;
    unites.add(u);
  }
  return String.fromCharCodes(unites);
}

const _debitsV1L3 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0];
const _debitsV2L3 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0];

Future<int?> _dureeMp3(RandomAccessFile raf, int taille, int debut) async {
  final b = await _lire(raf, debut, 16384);
  for (var i = 0; i + 4 < b.length; i++) {
    if (b[i] != 0xFF || (b[i + 1] & 0xE0) != 0xE0) continue;
    final version = (b[i + 1] >> 3) & 0x03; // 3 = MPEG1, 2 = MPEG2, 0 = MPEG2.5
    final couche = (b[i + 1] >> 1) & 0x03; // 1 = Layer III
    final idxDebit = (b[i + 2] >> 4) & 0x0F;
    final idxFreq = (b[i + 2] >> 2) & 0x03;
    if (version == 1 || couche != 1 || idxDebit == 0 || idxDebit == 15 || idxFreq == 3) continue;
    final mpeg1 = version == 3;
    final freqs = mpeg1 ? [44100, 48000, 32000] : version == 2 ? [22050, 24000, 16000] : [11025, 12000, 8000];
    final freq = freqs[idxFreq];
    final debit = (mpeg1 ? _debitsV1L3 : _debitsV2L3)[idxDebit] * 1000;
    final echantillons = mpeg1 ? 1152 : 576;
    final mono = ((b[i + 3] >> 6) & 0x03) == 3;
    // En-tête Xing / Info (fichiers VBR) : nombre total de trames.
    final decalage = i + 4 + (mpeg1 ? (mono ? 17 : 32) : (mono ? 9 : 17));
    if (decalage + 12 <= b.length) {
      final marque = ascii.decode(b.sublist(decalage, decalage + 4), allowInvalid: true);
      if ((marque == 'Xing' || marque == 'Info') && (b[decalage + 7] & 0x01) != 0) {
        final trames = _be32(b, decalage + 8);
        if (trames > 0) return (trames * echantillons * 1000 / freq).round();
      }
    }
    if (debit > 0) return ((taille - debut - i) * 8 * 1000 / debit).round();
    return null;
  }
  return null;
}

// ---------------------------------------------------------------- OGG

Future<void> _ogg(RandomAccessFile raf, int taille, Tags t) async {
  final debut = await _lire(raf, 0, taille < 262144 ? taille : 262144);
  final paquets = _donneesOgg(debut);
  int? frequence;
  var opus = false;

  final ident = _chercher(paquets, [0x01, 0x76, 0x6f, 0x72, 0x62, 0x69, 0x73]); // \x01vorbis
  if (ident >= 0 && ident + 16 <= paquets.length) {
    frequence = paquets[ident + 12] |
        paquets[ident + 13] << 8 |
        paquets[ident + 14] << 16 |
        paquets[ident + 15] << 24;
  } else if (_chercher(paquets, ascii.encode('OpusHead')) >= 0) {
    opus = true;
    frequence = 48000;
  }

  var c = _chercher(paquets, [0x03, 0x76, 0x6f, 0x72, 0x62, 0x69, 0x73]); // \x03vorbis
  if (c >= 0) {
    c += 7;
  } else {
    c = _chercher(paquets, ascii.encode('OpusTags'));
    if (c >= 0) c += 8;
  }
  if (c >= 0) _commentaires(paquets, c, t);

  if (frequence != null && frequence > 0) {
    final n = taille < 65536 ? taille : 65536;
    final fin = await _lire(raf, taille - n, n);
    for (var i = fin.length - 14; i >= 0; i--) {
      if (fin[i] == 0x4f && fin[i + 1] == 0x67 && fin[i + 2] == 0x67 && fin[i + 3] == 0x53) {
        var granule = 0;
        for (var k = 7; k >= 0; k--) {
          granule = granule << 8 | fin[i + 6 + k];
        }
        if (opus) granule -= 312; // pré-saut habituel, négligeable
        if (granule > 0) t.dureeMs = (granule * 1000 / frequence).round();
        break;
      }
    }
  }
}

/// Recolle le contenu des pages OGG (sans leurs en-têtes).
Uint8List _donneesOgg(Uint8List b) {
  final out = BytesBuilder();
  var p = 0;
  while (p + 27 <= b.length) {
    if (!(b[p] == 0x4f && b[p + 1] == 0x67 && b[p + 2] == 0x67 && b[p + 3] == 0x53)) break;
    final nSeg = b[p + 26];
    if (p + 27 + nSeg > b.length) break;
    var n = 0;
    for (var s = 0; s < nSeg; s++) {
      n += b[p + 27 + s];
    }
    final debut = p + 27 + nSeg;
    final fin = debut + n > b.length ? b.length : debut + n;
    out.add(b.sublist(debut, fin));
    p = debut + n;
  }
  return out.toBytes();
}

int _chercher(Uint8List b, List<int> motif) {
  outer:
  for (var i = 0; i + motif.length <= b.length; i++) {
    for (var k = 0; k < motif.length; k++) {
      if (b[i + k] != motif[k]) continue outer;
    }
    return i;
  }
  return -1;
}

int _le32(Uint8List b, int o) => b[o] | b[o + 1] << 8 | b[o + 2] << 16 | b[o + 3] << 24;

void _commentaires(Uint8List b, int p, Tags t) {
  if (p + 4 > b.length) return;
  p += 4 + _le32(b, p); // chaîne « vendor »
  if (p + 4 > b.length) return;
  final nb = _le32(b, p);
  p += 4;
  for (var i = 0; i < nb && p + 4 <= b.length; i++) {
    final n = _le32(b, p);
    p += 4;
    if (n < 0 || p + n > b.length) return;
    // Les images (METADATA_BLOCK_PICTURE) sont grosses : on ne décode que les petits champs.
    if (n < 4096) {
      final s = utf8.decode(b.sublist(p, p + n), allowMalformed: true);
      final eg = s.indexOf('=');
      if (eg > 0) {
        final cle = s.substring(0, eg).toUpperCase();
        final val = s.substring(eg + 1);
        switch (cle) {
          case 'TITLE':
            t.titre ??= val;
          case 'ARTIST':
            t.artiste ??= val;
          case 'ALBUM':
            t.album ??= val;
          case 'GENRE':
            t.genre ??= val;
        }
      }
    }
    p += n;
  }
}
