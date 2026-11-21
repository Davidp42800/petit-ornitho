# Chants : audit Xeno-canto

Examen du 30 septembre 2026. Aucun enregistrement importé, écouté ou certifié par cet audit. Le prototype ne contient pas encore de jeu audio.

## Valeur de la source

Xeno-canto est une collection communautaire pertinente pour sélectionner des chants. Naturalis décrit son utilisation en recherche et en reconnaissance acoustique : https://www.naturalis.nl/en/follow-our-stories/a-birdsong-ai-joins-worlds-biggest-bird-sound-forum

La fiabilité de la collection ne garantit pas chaque extrait. Une publication scientifique souligne que les vocalisations ne sont pas systématiquement localisées dans le temps et que les espèces d'arrière-plan peuvent manquer dans les annotations : https://repository.naturalis.nl/pub/801202/Ghani-2025-Impact-of-transfer-learning.pdf (Scientific Reports, 2025, DOI 10.1038/s41598-025-00996-2).

Une note de qualité sonore A/B n'est pas une certification taxonomique. Un enregistrement peut contenir plusieurs espèces ; une découpe arbitraire peut manquer le chant annoncé. L'identification automatique peut aider au contrôle, sans remplacer la validation de l'extrait.

## Ancien import examiné

Fichier local : `/Users/david/projects/oiseaux.ch-my-bird-journal/supabase/functions/species-info/index.ts`, fonctions `fetchXenoCanto`, `parseXenoCantoRecordings`, `normalizeRecordingType` et `cacheRecordings`.

- Recherche API v3 par nom scientifique, d'abord en Suisse avec filtre de qualité, puis qualité A sans restriction géographique, puis sans filtre de qualité.
- Conservation des cinq premiers résultats sans comparaison du taxon retourné avec l'espèce attendue. L'interface ne conserve pas les champs taxonomiques de la réponse.
- Association au `species_code` demandé lors de la mise en cache. Ce rattachement est présumé par la recherche, pas vérifié indépendamment.
- Aucun filtre imposant « song ». La normalisation teste `call` avant `alarm` et `flight` : « alarm call » et « flight call » sont donc ramenés à `call`. Un type absent devient aussi `call`.
- Une qualité absente devient artificiellement `C` ; auteur absent devient `Unknown`.
- Le cache conserve identifiant XC, URL, auteur, type, qualité, lieu et durée, mais pas la licence, le taxon source, le statut d'identification ni les espèces d'arrière-plan.

Ces lacunes ne prouvent pas qu'un fichier est mal identifié ; elles empêchent de garantir l'ensemble des correspondances. L'ancienne base distante reste inaccessible avec les permissions actuelles du connecteur. Aucun inventaire actuel de ses fichiers n'a donc été contrôlé.

## Règles retenues pour la future sélection

Conserver une petite sélection éditoriale, sans reprendre l'ancien import automatique ni sa logique de jeu.

1. Identifier chaque candidat par son identifiant XC et sa page permanente ; conserver la réponse source datée, le nom scientifique attendu et le nom scientifique retourné. N'accepter une différence de nomenclature qu'avec une correspondance taxonomique documentée ; ne pas comparer seulement les noms communs.
2. Choisir une vocalisation explicitement de type chant pour les défis « chant ». Conserver les types originaux et distinguer cri, alarme et chant ; une donnée absente reste inconnue.
3. Présélectionner la qualité A/B et privilégier Suisse ou régions européennes voisines, sans confondre lieu d'enregistrement et preuve de présence de l'espèce en Suisse. Aucun repli automatique vers une qualité non contrôlée.
4. Examiner la fiche et les discussions d'identification ; écarter les identifications inconnues, contestées ou insuffisamment documentées. Vérifier les autres espèces audibles, même si le champ arrière-plan est vide.
5. Faire écouter et valider l'extrait exact : espèce cible nettement audible, chant représentatif, pas de confusion avec un voisin plus fort. Conserver les bornes temporelles, le nom du validateur, la date et la justification. Une conformité des métadonnées seule ne vaut pas validation acoustique.
6. Conserver auteur, lien, licence propre au fichier et éventuelles transformations. Vérifier la compatibilité avec la diffusion prévue avant inclusion. Ne pas supposer que tous les fichiers ont la même licence.
7. Garder les candidats hors du jeu jusqu'à validation complète ; statuts `candidate`, `validated`, `rejected`. Recontrôler les fiches avant diffusion et retirer un extrait si son identification est ensuite contestée.

Cette procédure est une règle de sélection documentée, pas encore un validateur logiciel déployé. Les pages générales/API de Xeno-canto ont refusé l'accès automatisé pendant cet audit : le contrat API courant devra être vérifié avant d'écrire un nouvel importeur. Aucun accès ni aucune clé de l'ancien projet n'a été contourné.

## Implémentation du 3 octobre 2026

Les plateaux Flutter `ListeningScreen` implémentent deux jeux libres sans XP : chant → photo et nom → photo + chant. Les boutons d'écoute, arrêt, choix, validation, nouvelle tentative, bilan et rejeu sont câblés. Le lecteur audioplayers 6.5.1 s'arrête au changement de question, à la sortie et lors du passage en arrière-plan. Une panne de lecture autorise une nouvelle tentative et ne constitue pas une réponse incorrecte.

**Le catalogue `assets/data/recordings.json` reste vide : ces jeux ne sont donc pas activés.** Les tests injectent des métadonnées fictives et un lecteur simulé ; ils ne prouvent ni la lecture d'un vrai fichier ni son identification acoustique. Aucun fichier distant n'a été téléchargé, aucune validation humaine inventée.

Chaque entrée devra contenir : `id`, `species_id`, `scientific_name` identique au taxon de la fiche, `url` HTTPS, `source` HTTPS, `author`, `license`, `license_url` HTTPS, `type: song`, `status: validated`, `identification_disputed: false`, `reuse_approved: true`, `reviewer`, `reviewed_at`, `review_note`, `start_ms` et `end_ms` (extrait de 1 à 30 000 ms). Le validateur logiciel exclut les fiches incomplètes, contestées, non autorisées ou de taxon différent, et retient au maximum un extrait par espèce. Il faut au moins deux espèces éligibles. L'URL devra aussi être testée dans le navigateur de diffusion (disponibilité, décodage, CORS et recherche temporelle).

Le contrôle informatique de ces champs ne remplace pas l'écoute experte des bornes exactes. Les jeux restent en attente de cette sélection.

## Test API réel — 3 octobre 2026

La clé configurée dans Supabase fonctionne. Recherche v3 `sp:"Parus major" grp:birds type:song q:">C"` : 2 637 résultats. Première page de 500 : aucun chant pur admissible après le filtre strict sans NC ; cela ne signifie pas absence globale. Recherche supplémentaire `lic:PD` : 4 résultats CC0, dont 3 chants purs de qualité B (XC1095936, 32 s ; XC730822, 16 s ; XC707385, 22 s), tous déclarés identifiés et enregistrés en France. Importés dans `species_recordings` en **candidate**. Aucun publié, aucune validation acoustique prétendue.

`status` est une propriété de réponse, pas le tag `status:identified` : le premier essai a renvoyé HTTP 400. Le filtre s'effectue après réception. L'API documente `lic:PD` pour le domaine public. Le filtre large peut masquer des sons libres derrière de nombreuses pages NC : utiliser les filtres de licence/pagination pour l'import complet.

Le test serveur utilise un jeton temporaire distinct de la clé Xeno-canto, une réservation atomique et une requête fixe bornée. La clé Xeno-canto n'est jamais récupérée côté ordinateur, navigateur ni dépôt. Les réponses publiques réduites sont dans `data/imports/xeno-canto/` ; pas de coordonnées précises conservées. Les règles de licence rejettent NC et ND au niveau de l'import, de la publication SQL et de Flutter.

Source : https://xeno-canto.org/explore/api et https://xeno-canto.org/help/search.
