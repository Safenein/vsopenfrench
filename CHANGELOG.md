# Journal des modifications

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
`vs-release` transforme la section « Non publié » en section versionnée.

## [Non publié]

- Relecture : héraldique en émaux (« Bordure de gueules », « Lion de sable », « Champ au
  naturel ») ; noms de fruits de wcfefcompat repris de Wildcraft: Fruits and Nuts pour que les
  deux mods concordent ; Pipeleaf : « scaferlati » au lieu de « brins » ; acier de cémentation
  (skeletons), « Pillard » (allclasses), essences de bois de bdtree alignées (aculinaryartillery).
- Modpack de référence à jour (chiseltools 1.17.8, foodshelves 3.1.1, ndltreegrowth 2.8.0,
  playercorpseforkedazu 1.15.2, realsmoke 2.0.0-pre.6, smithingplusplus 1.10.6) ; ndltreegrowth :
  sacs de jute renommés (15 textes), 17 clés obsolètes retirées.
- Squelette du mod, outillage d'audit, de vérification et de publication.
- Traduction complète de Wildcraft x Expanded Foods Compatability (wcfefcompat 1.2.7, 5 447 textes),
  générée par `vs-gen` depuis `gen/wcfefcompat.json`.
- Traduction complète de l'héraldique : Heraldry Core, Capes, Banners (2.0.0) et More Banners
  (1.3.3), 2 240 textes, générée par `vs-gen` depuis `gen/heraldique.json`.
- Traduction complète de Pipeleaf (2.6.1, 1 461 textes), générée par `vs-gen` depuis
  `gen/pipeleaf.json`.
- Lexique plus ancien et authentique : Pholiote marginée, Strophaire cubaine, Pholiote remarquable,
  Armillaire couleur de miel ; charrette (et non chariot), coupe (et non gobelet), eau-de-vie
  vieillie ou millésimée (et non brandy).
- vsopenfrench couvre aussi le périmètre des trois packs tiers avec ses propres traductions
  (4 035 textes de plus, 31 mods) : il n'a plus besoin d'eux. Les packs ne comptent plus dans
  l'audit, le lint et `vs-gen`.
- `vs-lint` ignore les textes sans deux lettres (nombres, ponctuation, lettre seule).
- `vs-check-updates` et workflow hebdomadaire : issue « traductions à faire » quand une nouvelle
  version d'un mod apporte des textes sans français ou rend des clés obsolètes.
- Textes manquants des 36 derniers mods du modpack (windowdisplay, substrate, aculinaryartillery,
  windchimes, effectlib, universaldisplaylib et une trentaine de petits trous) : `vs-audit` ne
  trouve plus aucun texte sans français dans le modpack de référence.
- Textes manquants d'Expanded Foods (2 956 : tartes mixtes, légumes émincés), générés par `vs-gen`
  depuis `gen/expandedfoods.json`.
- Traduction complète de Kobold Player Model (koboldrdx, 95 textes).
- Traduction complète de Skaven/Rat Player Model (239 textes : apparence, couleurs, réglages).
- Traduction complète de Skeletons (343 textes : modèles, apparence, classes, traits).
- `vs-lint` compare le texte affiché (sans balises ni puces) à `lint/identiques.txt`.
- Traduction complète de Better Ruins (295 textes, environ 11 000 mots : récits, lettres, quêtes des
  marchands).
- Traduction complète d'OrekiWoof's Simple Immersive Beehive (2.0.0, 134 textes).
- `vs-lint` accepte le texte traduit des pluriels `{p0:…}` et vérifie les paramètres `>>>nom<<<`.
- Textes manquants de mods déjà traduits : Alchemy (103), Bricklayers (69), Expanded Matter (25),
  Wool & More (21), Molds (13), Food Shelves (8), Hydrate or Diedrate (4).
