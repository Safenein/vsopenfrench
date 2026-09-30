# Contribuer

Ce projet existe pour que la traduction française des mods de Vintage Story se fasse **en
public** : chacun peut signaler une erreur, proposer une correction ou traduire un mod entier, et
chaque changement est relu et daté dans l'historique git. Toute contribution est bienvenue, d'une
faute de frappe à des milliers de lignes.

## Signaler un problème

Ouvrir une [issue](https://github.com/Safenein/vsopenfrench/issues/new/choose) :

- **Erreur de traduction** : le texte affiché en jeu, le mod, et la correction proposée.
- **Mod à traduire** : le mod (lien ModDB) et sa version.

Pas besoin de savoir où se trouve la clé : le texte vu en jeu suffit.

## Proposer une traduction

### Sans rien installer

Pour une correction ou quelques clés, l'éditeur de GitHub suffit : ouvrir le fichier
`assets/<mod>/lang/fr.json`, cliquer sur le crayon, modifier, proposer la modification. La CI
vérifie le fichier dans la pull request et signale les erreurs.

### Avec l'environnement complet

Il faut [Nix](https://nixos.org/download) et [devenv](https://devenv.sh/getting-started/). Puis :

```sh
devenv shell
vs-audit            # work/todo/<mod>.json : textes encore sans français, par mod
vs-lint             # vérifie les fichiers du dépôt
vs-test             # optionnel : charge le mod dans un vrai serveur en français
```

1. Choisir un mod dans `work/todo/`, ou dans les [priorités](docs/audit-2026-09-30.md#priorités-et-outil-de-travail).
   Le signaler dans une issue pour éviter de traduire à deux.
2. Copier son contenu dans `assets/<mod>/lang/fr.json` (voir « Organisation ») et traduire les valeurs.
3. `vs-lint`, puis ouvrir une pull request. Le hook pre-commit lance `vs-lint` à chaque commit.

## Organisation

Un fichier par mod traduit, dans le dossier du mod (son modid) :

```
assets/
├── wcfefcompat/lang/fr.json
├── smithingplusplus/lang/fr.json          # contient aussi ses clés "game:…"
└── expandedfoods/lang/
    ├── fr.json
    └── compatibility/primitivesurvival/fr.json
```

- Les clés sans `:` prennent le domaine du dossier, comme dans le `en.json` du mod.
- Les clés qu'un mod apporte à un autre domaine vont dans **son** fichier, préfixées :
  `"game:trait-…": "…"`. Une clé avec `:` garde son domaine, quel que soit le fichier.
- Les sous-dossiers `compatibility/<mod>/` reprennent le chemin du mod d'origine.

Exception : certains fichiers sont **générés** par `vs-gen` à partir de `gen/*.json`, ne pas les
modifier à la main :

- `assets/wcfefcompat/lang/fr.json` depuis `gen/wcfefcompat.json` (gabarits par type de produit,
  glossaire des fruits avec leur genre, clés traduites à la main) ;
- `assets/expandedfoods/lang/fr.json` depuis `gen/expandedfoods.json` (ingrédients des tartes mixtes,
  motifs anglais « A/B pie », noms spéciaux, légumes émincés) ;
- `assets/pipeleaf/lang/fr.json` depuis `gen/pipeleaf.json` (plantes, métaux, descriptions des
  mélanges par paire de plantes, clés traduites à la main) ;
- `assets/{heraldry,capes,heraldrybanners,morebanners}/lang/fr.json` depuis `gen/heraldique.json`
  (couleurs, motifs avec leur genre, clés traduites à la main). Les clés `heraldry:pattern-*`
  déclarées à la fois par capes et heraldrybanners vont dans `assets/heraldry`.

Pour corriger un nom ou une tournure, modifier le fichier de `gen/` puis relancer `vs-gen` ; la CI
refuse un fr.json qui n'est plus à jour.

Un fichier par mod se relit d'un bloc, s'envoie à l'auteur du mod, et se supprime le jour où le mod
se traduit lui-même.

## Règles de traduction

`vs-lint` (et la CI) refuse un fichier qui enfreint les règles marquées ✔.

- ✔ **Ne livrer que les trous.** Une clé déjà traduite par le mod lui-même ou par un autre mod
  n'est pas livrée : en cas de doublon, la dernière valeur chargée gagne, et l'ordre de chargement
  n'est pas maîtrisé. Exception : les packs de traduction tiers (`TRANSLATION_PACKS` dans
  `devenv.nix` : modtraductionsfr, vintagestoryfr, frtraductionmods) ne comptent pas, car
  vsopenfrench couvre leur périmètre avec ses propres traductions.
- ✔ **Clés à l'identique**, jokers `*` compris (`block-hay-aged-*`), sinon elles ne remplacent pas l'anglais.
- ✔ **Conserver les paramètres** `{0}`, `{1}`, `>>>nom<<<`… et les balises (`<a href="handbook://…">`, `<font>`).
  Conserver aussi les `\n` (avertissement seulement).
- ✔ **JSON strict en UTF-8** : pas de commentaires, pas de virgule finale, pas de BOM.
- ✔ **Pas de clé du jeu de base** : les trous du jeu lui-même se signalent à la
  [traduction officielle](https://crowdin.com/project/vintage-story-game).
- **Lexique ancien et authentique** : entre deux termes, préférer le plus ancien et le plus
  authentique (« Pholiote marginée » plutôt que le calque « Chapeau ondulé », « charrette », « coupe »,
  « eau-de-vie » plutôt que « brandy »), y compris quand le jeu de base n'a qu'un calque.
- **Vocabulaire du jeu de base** (`game/lang/fr.json`) : « Cuproplomb » et non « molybdochalkos »,
  majuscules comme « Clous et bandes (Bismuth) ». Chercher le terme officiel avant d'en inventer un.
- Une valeur anglaise vide ne se traduit pas (`vs-audit` l'ignore déjà).
- Un texte laissé identique à l'anglais déclenche un avertissement. Si c'est voulu (nom propre,
  emprunt comme « Limoncello »), l'ajouter à `lint/identiques.txt`.
- Le mod ne déclare **aucune dépendance** hormis le jeu : une traduction ne s'applique que si son
  mod est installé.

## Licence des contributions

Le dépôt est sous [CC-BY-4.0](LICENSE). En proposant une contribution, vous acceptez qu'elle soit
publiée sous cette licence et vous confirmez en être l'auteur. **Ne pas copier les traductions
d'autres packs** (Pack de Traduction Française, Mod Traductions FR, French Translation Pack…) sans
l'accord écrit de leurs auteurs : elles ne sont publiées sous aucune licence qui le permette.
