// Ouverture des liens web : dans Brave si installé (Android), sinon dans le
// navigateur par défaut.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const _canal = MethodChannel('bzh.alr.trodans/liens');

/// Ouvre [url] ; renvoie false si rien n'a pu l'ouvrir.
Future<bool> ouvrirLien(String url) async {
  var u = url.trim();
  if (u.isEmpty) return false;
  if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
  if (Platform.isAndroid) {
    try {
      final ok = await _canal.invokeMethod<bool>('ouvrir', {'url': u});
      if (ok == true) return true;
    } catch (_) {
      // canal indisponible : on passe par url_launcher
    }
  }
  try {
    return await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
