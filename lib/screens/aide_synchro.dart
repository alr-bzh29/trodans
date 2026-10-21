import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../storage.dart';
import '../widgets.dart';

const _lienFdroid = 'https://f-droid.org/packages/com.github.catfriend1.syncthingfork/';
const _lienGithub = 'https://github.com/Catfriend1/syncthing-android/releases';
const _lienSyncthing = 'https://syncthing.net/';

/// Courte aide pour synchroniser les données avec Syncthing.
class AideSynchroEcran extends StatelessWidget {
  const AideSynchroEcran({super.key});

  Future<void> _ouvrir(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) message(context, 'Lien copié : $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Depot.I.reglages;
    final titre = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    Widget etape(String n, String t, List<Widget> contenu) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 14, child: Text(n)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(t, style: titre), const SizedBox(height: 4), ...contenu],
                ),
              ),
            ],
          ),
        );
    Widget lien(String texte, String url) => Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(texte),
            onPressed: () => _ouvrir(context, url),
          ),
        );
    Widget code(String s) => Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText(s, style: const TextStyle(fontFamily: 'monospace')),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Synchroniser avec le PC')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'TroDañs enregistre tes cours et tes notes dans un dossier ordinaire. '
            'Syncthing copie ce dossier entre le téléphone, la tablette et le PC, '
            'directement entre tes appareils, sans passer par un service en ligne.\n\n'
            'Tant que la version PC n\'existe pas, la synchro sert déjà de sauvegarde.',
          ),
          const SizedBox(height: 20),
          etape('1', 'Sur le téléphone', [
            const Text('Installe « Syncthing-Fork » (Android 6 et plus).'),
            lien('Syncthing-Fork sur F-Droid', _lienFdroid),
            lien('ou l\'APK sur GitHub', _lienGithub),
            const Text('Dans l\'économie de batterie, mets-le aussi en « Pas de restriction ».'),
          ]),
          etape('2', 'Sur le PC (Linux Mint)', [
            const Text('Dans un terminal :'),
            code('sudo apt install syncthing'),
            const Text('Lance « Syncthing » depuis le menu (ou la commande syncthing), '
                'puis ouvre son interface dans le navigateur :'),
            code('http://127.0.0.1:8384'),
            lien('Site officiel de Syncthing', _lienSyncthing),
          ]),
          etape('3', 'Relier les appareils', [
            const Text('Sur le PC : Actions › Afficher l\'ID (un QR code s\'affiche).\n'
                'Sur le téléphone : onglet Appareils › + › scanne ce QR code.\n'
                'Accepte ensuite l\'appareil sur le PC.'),
          ]),
          etape('4', 'Partager le dossier de TroDañs', [
            const Text('Sur le téléphone : onglet Dossiers › + , avec ce chemin :'),
            code(r.dossierDonnees),
            const Text('Coche le PC dans la liste des appareils, puis enregistre. '
                'Sur le PC, accepte le partage et choisis par exemple ~/TroDans.'),
          ]),
          etape('5', 'La sonothèque (facultatif)', [
            const Text('Partage aussi ton dossier de musique, de la même façon :'),
            code(r.racineMusique),
            const Text('Sur la tablette, si la place manque, tu peux ne partager qu\'une partie.'),
          ]),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'À éviter : modifier le même cours sur deux appareils avant que la synchro '
                'soit passée. Syncthing garderait alors deux versions du fichier '
                '(« sync-conflict »), et TroDañs n\'afficherait que l\'originale.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
