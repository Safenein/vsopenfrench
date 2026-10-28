# Journal des modifications

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
`vs-release` transforme la section « Non publié » en section versionnée.

## [Non publié]

- vsopenfrench devient un pack *theme* : chargé après tous les mods, ses traductions s'affichent
  même quand un mod à dépendances livre un fr.json resté en anglais (armoryfork, pandaxskills,
  quiversfork, tabletopgames, electricalprogressiveindustry). `vs-test` vérifie qu'il charge en
  dernier.
- Caractéristiques de classe : un même trait portait deux noms, l'un dans la fiche du personnage
  (touche C), l'autre dans les recettes qui l'exigent. Le Tisserand d'Aldi's Classes avait bien
  « Drapier », mais sa fiche l'appelait « Couturier ». Noms alignés :
  - jeu de base (surcharges justifiées dans `lint/surcharges.txt`) : Drapier, Facteur d'arcs
    (ex-« Archer »), Raccommodeur (coquille), Impitoyable, Pillard, Précis, Pied léger,
    Débrouillard ;
  - Specialized Classes : 20 traits (Prudent, Pudique, Moissonneur, Laboureur, Charpentier de
    marine…) et « Imprudent », resté en anglais ;
  - Aldi's Classes : fiche du personnage en français pour Charbonnier, Boucher, Fermier, Fragile,
    Affamé, Bûcheron et Mineur, que seul allclasses traduisait ; « Sus à l'ennemi ! » ;
  - Rustbound Magic : « Recettes d'archimage » ; Armory : puce « • » au lieu de « â€¢ ».
- `vs-lint` : surcharges assumées listées dans `lint/surcharges.txt` (clé du jeu de base ou déjà
  traduite ailleurs), avertissement quand `trait-X` et `traitname-X` ne disent pas la même chose.
- Modpack de référence mis à jour (41 mods, dont Improved Metallurgy 1.2.1, Forgotten Armory,
  RP Voice Chat 2.6.6, Expanded Foods 2.0.0-dev.16, Window Display 1.1.0) et ses 748 nouveaux
  textes traduits :
  - Improved Metallurgy : aluminium (bauxite, alumine, cryolithe, potassium) et duralumin,
    infobulles du haut fourneau, des rigoles et de la cuve à laitier, commandes `/IM` ;
  - Forgotten Armory : armures d'écailles Qièxuē et brigandines Shìwèi Qīnjūn (153 pièces), et
    les quatre chroniques réécrites (gothique, Greenwich, varègue, dynasties chinoises) ;
  - RP Voice Chat : groupes vocaux ;
  - Expanded Foods (`vs-gen`) : fenouil, céréales grillées ;
  - Window Display : fenêtres classiques, volets extérieurs, vitres ; Universal Display Lib :
    ouverture et fermeture des présentoirs ;
  - carillons de porte (Wind Chimes), cornes skavens, soupières pleines (Aldi Classes), favoris des
    émotes, assiettes (Dishware), erreurs du four (A Culinary Artillery).
- Textes anglais modifiés retraduits : fenêtres « pliantes » (ex-« ouvrant à »), recettes de
  VS Roofing (grandes lauzes, bardeaux de métal), chaudières (Pipes and Power Expanded),
  convertisseur Bessemer, nodules polymétalliques des lacs, limite du soufflet.
- Clés disparues de l'anglais retirées (ppex, smex, vintageskavenrat, windchimes).
- `vs-check-updates` retient la release compatible de plus haute version et ne revient jamais en
  arrière : alchemy reste en 2.2.0-rc.12 malgré la publication d'une 2.1.23.
- Modpack de référence mis à jour une deuxième fois (45 mods, dont WCF/EF Compat 1.3.2,
  Forgotten Armory: Viking 2.0.0, Interesting Ore Gen 3.0.2, Shipwright 1.5.1, Carry On
  2.0.0-rc.1, alchemy 2.2.0-rc.14) et ses nouveaux textes traduits (3 420 clés ajoutées) :
  - WCF/EF Compat (`vs-gen`) : clés réorganisées par le mod, fichier régénéré (2 587 clés) ;
    tartes aux fruits secs, portions, marcs (« Marc de raisin »), vins de fleurs vieillis,
    ambroisie ;
  - Expanded Foods (`vs-gen`) : ingrédients liquides des recettes, nommés comme la boisson dans
    son récipient (« Cidre de pomme »), nougatines grillées, page du guide sur les bonbons ;
  - Alchemy : 288 boutures ; Aldi's Classes race patch : races et leurs caractéristiques (125
    textes) ; Aldi's Classes : verre ouraline, guide des recettes des classes ;
  - Forgotten Armory: Viking 2.0.0, refondu : casques, plastrons et jambières Bjarnhǫldr et
    Ragnbjörn ; ornement Metallicus Arietinus dans les chroniques et l'établi de décoration ;
  - Interesting Ore Gen 3.0 : guide retraduit (amas, couches, failles, cheminées, roche
    encaissante) ;
  - Shipwright : færing ; Window Display : volets coulissants ; Universal Display Lib :
    présentation dans les blocs sculptés et au sol ; Carry On, effectlib, dead (gravures,
    blessures d'Injury Expanded), downed, Purposeful Storage (armoire d'apothicaire).
- Textes anglais modifiés retraduits : coûts de construction de Shipwright, bac à ressources,
  pot temporel (Aldi's Classes), réglage de tolérance (SlowTox), fenêtres de Window Display.
- Clés disparues de l'anglais retirées (faviking, wrustbound, aldiclasses, carryon, effectlib,
  facore, slowtox).
- Workflow `mods.yml` : le rapport des 19 et 26 octobre dépassait les 65 536 caractères d'une
  issue (lignes de `vs-lint` citant des textes anglais entiers), qui n'a pas pu être créée.
  Lignes coupées à 300 caractères, rapport tronqué au-delà de 60 000 octets, bannière de devenv
  retirée de la liste des mods.
- Elk Adornments 2.0.15 : schémas de masque de wapiti (crocs, cornes, corne nasale, plumets,
  ramure, anneaux, garniture) et deux couvertures rares (« La Flèche brisée », « Flèche dorée ») ;
  les anciens masques personnalisables obsolètes et les pages « Personnalisation de masque » du
  guide, disparus du mod, sont retirés (299 clés). Mises à jour sans nouveau texte : alchemy
  2.2.0-rc.15, deciduoustrees 2.1.0, effectlib 1.2.2, WCF/EF Compat 1.3.3.

## [0.4.0] - 2026-10-04

- Modpack de référence étendu de 185 à 210 mods, et leurs 5 476 textes sans français traduits :
  Forgotten Armory (Core, Chinese Dynasties, Varangian, Greenwich, Gothic, Landsknechts, Viking),
  Weapon Pack Alpha - Rebalanced, Fauna of the Stone Age (Capreolinae, Felinae ; Pantherinae se
  traduit déjà lui-même), Eternal Seraph: Dovidarium, Flowerbeds, Dishware, More Lanterns,
  Duskridge Settlers: Core, Sauna, EarthLiving Mine Transport, Steelmaking Expanded, Pipes and
  Power Expanded, Logging Expanded, Vanilla Varnished Planks, Japanese Architecture et Clothier's
  Heirlooms. Gondola Cable Car se traduit déjà lui-même. Vocabulaire d'époque quand il existe :
  salade, armet, bourguignotte, lansquenet, espadon, bec-de-corbin, lit de fusion, vent chaud,
  rigole de coulée, brocard.
- Notice Board 3.0.4 dans le modpack de référence (déjà traduit par son auteur).
- Hanging Storage Vessels 1.1.1 dans le modpack de référence, traduit (jarres suspendues et inclinées).
- `vs-audit` ne compte plus comme traduite une valeur vide ou restée en anglais dans le fr.json
  d'un mod, et voit les noms des blocs ciselés des schémas. 1 316 textes de plus traduits, dont :
  - Better Ruins : plus de 800 noms et descriptions de blocs ciselés des ruines (« Vieux tabouret »,
    « Four »…), et ceux de More Banners, Temporal Technology (noms laissés en tchèque),
    Th3Dungeon ;
  - Primitive Survival : description de la terre agricole avec sillon, aide du fumoir, lombrics ;
  - Butchering : pain de sang au seigle ;
  - Armory (acier météorique), XSkills/XLib (effets, aptitudes), Millwright, OptiTime,
    Footprints, quivers, Racial Equality, All Classes, etc. Les textes identiques en français
    (Banjo, Cognac, Jujube…) sont déclarés dans `lint/identiques.txt`.

## [0.3.0] - 2026-10-02

- Intégration d'[Aethernia Translation](https://mods.vintagestory.at/show/mod/64379) 0.0.15
  (DiZurix, avec son accord) : 14 633 textes pour 58 mods. Seuls les trous sont repris : quand nous
  avions déjà une traduction, la nôtre est gardée, et les clés que les mods traduisent eux-mêmes
  sont écartées. Vocabulaire aligné sur le jeu de base (« engrenage temporel », « séraphin »).
- Modpack de référence étendu de 119 à 185 mods (Rustbound Magic, Steep and Brew, Elk
  Accessories/Adornments, Portcullis, Posts and Beams, Shipwright, Combat Overhaul Fork…) ;
  leurs 384 textes que le pack ne couvrait pas sont traduits (XSkills : couture, brasserie,
  navigation, équitation ; Vinconomy, Armory, Downed, Dead…).
- Build nightly de `main` en pré-release GitHub (tag `nightly`), testé en jeu.
- skeletons : 4 attributs de personnage retirés, désormais traduits par Combat Overhaul Fork.
- Retraduits depuis l'anglais : environ 3 300 textes intégrés avec Aethernia se sont révélés
  identiques à Mod Traductions FR (Deadykass_), pack dont nous n'avons pas l'accord. Sont
  concernés Rustbound Magic (2 811 textes), Art of Growing, AOG Breeding, Chisel Tools,
  Sprinklers, Smithing Plus, VS Roofing et Wind Chimes. Rustbound Magic est harmonisé au passage :
  noms de sorts, paliers accordés (« Hache majeure », « Ceinture mineure »), « chiffre de sort »,
  « four à arc », matériaux accentués (éthérium, xégonite, nethérite).
- Relecture complète, avec corrections :
  - seuils d'humidité des arroseurs (85 % et 95 %) ;
  - températures de récolte de la résine (Chef's Tricks) ;
  - espaces finales des messages de forage (Betterer Prospecting) ;
  - chiffres et avertissements de Rustbound Magic (15 % de stabilité, objets perdus du sac
    invoqué) ;
  - masques obsolètes d'Elk Adornments signalés comme tels ;
  - « wapiti » au lieu d'« élan » pour *elk* ;
  - « cuproplomb », « arcracheurs », « locustes » ;
  - champignons de Steep and Brew selon le lexique du dépôt (« pholiote marginée »,
    « hygrophore conique ») ;
  - tartes et semences d'AOG Breeding alignées sur le jeu de base ;
  - plaquebière dans Expanded Foods ;
  - ordre « vin de framboise fort » ;
  - « de cendrée » en héraldique ;
  - accords de couleur dans Abyssal Depths ;
  - coquilles diverses.

## [0.2.0] - 2026-10-01

- Nouveaux mods du modpack de référence (119 mods) : Aldi's Classes et ses extensions (advanced
  features, race patch ; 1 369 textes : classes, traits, remèdes, soupières, havresac), Valkyrja
  Hair (118), Horns & Antlers (24), More Undergarments Updated (24).
- Logo et `modicon.png` en 480 × 480 px (format demandé par la ModDB).

## [0.1.0] - 2026-10-01

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
