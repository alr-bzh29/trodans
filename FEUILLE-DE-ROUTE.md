# Feuille de route TroDañs

## Version de test (0.1.x) — faite
- Scan de la sonothèque (`Danse/Titre - Artiste.mp3`), recherche
- Cours : date, numéro, thème, déroulé par section, notes
- Mode « en cours » : lecteur, cases à cocher, présents, mystère masqué, fiche avec mini-lecteur
- Notes par danse, récap WhatsApp, aide Syncthing, À propos

## Fait depuis (0.1.7 à 0.1.8 et branche `refonte-corpus`)
- Danse + un ou plusieurs titres par ligne ; notes Markdown (cours et danses) ; couleurs
- Lecture des tags au scan (titre, artiste, album, genre, durée)
- Parties fixes (échauffement, MEJ, mystère, plusieurs danses chacune) + **corpus**
  (révisions / nouveautés mêlées, étiquette en couleur) ; plus d'extras
- Glisser-déposer en préparation et pendant le cours ; ajout / retrait en cours
- Danse saisie librement avec lien vidéo ouvert dans Brave
- Récap dans l'ordre du cours ; heure actuelle + temps restant / dépassement ;
  heures de début et de fin réglables
- Pointage des présents : liste de prénoms (Réglages), pointage à tout moment,
  visiteurs hors liste, venues par danseur ; danseurs désactivés, jamais supprimés

## À faire — demandes d'André
- [ ] **Photos du cours** : prises depuis la fiche du cours, rangées à côté du cours
      (`cours/photos/AAAA-MM-JJ-n.jpg`), réduites (~1–2 Mo), synchronisées
- [ ] **Bilan / AG** : dates de la saison, nombre de cours, heures (début/fin), présence (dont venues par danseur), danses vues ;
      liste des danses (ordre alphabétique et/ou par type) ;
      **tableau avec une ligne par cours, incluant les notes du cours**
- [ ] **Calendrier en page d'accueil** : vue mensuelle, cases en couleur (cours, vacances
      zone B, relâches, événements : musiciens, galette, fête…), un appui ouvre la fiche du cours ;
      vacances importées automatiquement (API Éducation nationale) + événements saisis à la main
- [ ] **Bloc « Réserve »** en fin de cours (préparation et mode en cours) : danses de secours
      si le cours avance plus vite que prévu ; une danse de réserve jouée passe dans le
      corpus (et donc dans le récap)
- [ ] **Recueil d'idées / danses à voir** : liste de danses avec notes (Markdown),
      dans laquelle puiser pour préparer les cours (ajout direct dans un cours)
- [ ] **Historique d'une danse** : à la sélection, nombre de fois jouée, dates et ancienneté
      (« il y a 3 semaines »), dans la fiche et au moment de l'ajouter à un cours ;
      seules les danses cochées « faites » comptent
- [ ] Tags (#tag) communs à titres, danses, cours ; filtres inclure/exclure
- [ ] Lecteur : tempo réglable, repères enregistrés, aperçu 15 s, fondu programmé
- [ ] Fiches Danse complètes (famille, liens, « en savoir plus » hors ligne)
- [ ] Version PC Linux
- [ ] Sauvegarde / restauration zip `TroDans-VX-AAAAMMJJ-HHMM.zip` (sonothèque en option,
      N dernières conservées) ; suppression totale avec sauvegarde + double confirmation
- [ ] Gestion des conflits Syncthing (`sync-conflict`)
- [ ] APK séparés par architecture (plus légers, utile pour la Fire 7)

## Idées pour après la V2
- [ ] **Import d'une playlist m3u comme cours** : chaque titre devient une ligne ;
      on donne un nom de danse à chacun et on les répartit dans les parties
      (échauffement, mise en jambes, mystère, corpus révision / nouveau)

## Appareils
- POCO X3 (Android 12) — téléphone des cours
- Fire 7 5e gén. sous LineageOS 7.1.2 (Android 7.1)

## Questions ouvertes
- Nom de la danse : tag genre prioritaire sur le dossier — à confirmer selon les tags réels
- Heures de cours : garder les heures propres à chaque cours si l'horaire change en saison ?
