# TroDañs

Gestion des cours de danses bretonnes : sonothèque, préparation des cours,
mode « en cours » avec lecteur, récap WhatsApp.

Conception : André Rodach — Développement : Claude (Anthropic).

## Compilation

L'APK Android est compilé par GitHub Actions à chaque envoi sur `main`
(`.github/workflows/build.yml`) et publié dans les *Releases* (pour Obtainium).

- Le dossier `android/` n'est pas versionné : il est généré par `flutter create`,
  puis adapté par `tool/patch_android.py` (permissions, lecture en arrière-plan).
- La clé de signature est versionnée **chiffrée** (`android-signing/trodans.jks.enc`).
  Son mot de passe est le secret `KEYSTORE_PASSWORD` du dépôt. Sans la même clé,
  une mise à jour ne peut pas s'installer par-dessus la version précédente.

## Données

- Sonothèque : `Danse/Titre - Artiste.mp3` ; les dossiers commençant par `_` ne sont pas des danses.
- Dossier de données (à synchroniser avec Syncthing) :
  - `cours/AAAA-MM-JJ.json` : un fichier par cours ;
  - `danses/<nom>.json` : la note personnelle de chaque danse.
- Réglages et index de la sonothèque : propres à chaque appareil.
