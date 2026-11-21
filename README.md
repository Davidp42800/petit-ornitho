# Petit ornitho

Jeu Flutter de découverte des oiseaux pour tous les ornithos en herbe.

## Web

`flutter pub get --enforce-lockfile`, puis `flutter build web --release --pwa-strategy=none` et `python3 scripts/compact_web_catalogues.py build/web`.

Vercel construit la branche `main` avec Flutter 3.41.6 via `scripts/vercel-build.sh` et sert `build/web`. Domaine : https://les-oiseaux.ch.

Ce dépôt de publication contient le client web, ses médias embarqués et ses tests. Les imports éditoriaux, outils locaux et migrations serveur restent dans le dépôt de travail ; le build ne modifie aucune donnée serveur. Les anciens chemins photo `catalog/` sont résolus vers `reviewed/` par le client.
