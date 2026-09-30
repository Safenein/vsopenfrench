# CLAUDE.md

Mod de contenu Vintage Story (`modid` `vsopenfrench`) qui livre des traductions françaises
pour les textes de mods que personne ne traduit. Aucun code C# : `modinfo.json`, `modicon.png` et
des fichiers `assets/<domaine>/lang/fr.json`. Le contexte complet (chiffres, ordre de chargement,
priorités) est dans `docs/audit-2026-09-30.md`. On écrit en français.

## Environnement

Tout est déclaré dans `devenv.nix` (paquets, dérivations, scripts, hooks) ; lancer les commandes
dans `devenv shell`.

- `vsServer` : serveur officiel du jeu (`gameVersion`, tarball du CDN). Donne `VS_GAME_ASSETS`.
- `vsMods` : modpack de référence construit depuis `mods.json` (zips ModDB, ré-empaquetés avec
  des `/`). Donne `VS_MODS_DIR`. Reproduit le modpack de bihan au jeu 1.22.7 (112 mods).
- Les scripts Python partagent `pyLib` (lecture tolérante des lang des mods, résolution des domaines).

| Commande | Rôle |
| --- | --- |
| `vs-audit [sortie]` | textes sans français → `work/todo/<modid>.json` (par domaine). Les fr.json du dépôt comptent comme traduits. Référence : 14 405 clés / 55 mods sans aucune traduction du dépôt |
| `vs-gen [--check]` | génère les fr.json traduits par gabarits depuis `gen/*.json` : `wcfefcompat.json` (produits × fruits accordés), `expandedfoods.json` (tartes mixtes « A/B pie » × glossaire d'ingrédients), `pipeleaf.json` (mélanges × plantes, pipes × métaux) et `heraldique.json` (motifs × couleurs accordées pour heraldry, capes, heraldrybanners, morebanners ; clé partagée entre ces mods → `assets/heraldry`). Échoue sur toute clé anglaise non couverte. `--check` dans `enterTest` |
| `vs-lint` | JSON strict UTF-8 sans BOM, sans doublon ; clé présente en anglais dans le modpack ; non traduite ailleurs ; mêmes `{n}`, `>>>nom<<<` et balises que l'anglais (le texte des pluriels `{p0:…}` se traduit). Hook pre-commit |
| `vs-build` | `dist/vsopenfrench_<version>.zip`, chemins en `/`, horodatage fixe |
| `vs-test` | serveur jetable dans `work/server/` (`ServerLanguage: fr`), échoue sur `Failed to load language file` |
| `vs-install` | copie le zip dans `~/.config/VintagestoryData/Mods` (`VS_CLIENT_MODS` pour changer) |
| `vs-logo` | régénère `docs/logo.png` (512 px, ModDB/GitHub) et `modicon.png` (128 px) ; police Libertinus Serif de nixpkgs |
| `vs-release <version>` | met à jour modinfo + CHANGELOG, commit, tag `v<version>`, push, `gh release create` |
| `vs-lock-mods <dossier> [jeu]` | régénère `mods.json` via l'API ModDB (`api/mod/<modid>`, repli sur l'urlalias ; champ `moddb` pour forcer un id) |

Hooks pre-commit (lancés par prek, sur les fichiers suivis par git) : `vs-lint`, `nixfmt`, `actionlint`.

## CI (GitHub Actions)

`.github/workflows/ci.yml`, sur chaque push, PR et à la demande ; l'installation de Nix et devenv
est factorisée dans `.github/actions/setup-devenv`.

- **Validation** : `devenv test` (hooks + enterTest), zip en artefact, total de `vs-audit` dans le
  résumé. Sous GitHub Actions, `vs-lint` émet des annotations `::error file=…,line=…::`, visibles
  sur la ligne fautive d'une PR (utile aux contributeurs sans Nix).
- **Chargement en jeu** : `vs-test` ; logs du serveur en artefact en cas d'échec.
- Le store Nix (serveur + modpack, ~2 Go) est mis en cache par `cache-nix-action`, clé sur
  `devenv.lock`, `devenv.nix` et `mods.json`. Purge seulement sur push (jeton en lecture seule
  dans les PR de forks).

Changer de version du jeu : modifier `gameVersion` et le hash de `vsServer`, relancer
`vs-lock-mods` sur le nouveau modpack, puis `vs-audit`.

## Règles de traduction et organisation

La référence est `CONTRIBUTING.md` (organisation des fichiers, règles, licence), écrite pour les
contributeurs : la tenir à jour plutôt que de dupliquer ici. En bref : ne livrer que les trous, un
fichier par mod (`assets/<modid>/lang/fr.json`, clés d'autres domaines préfixées), aucune
dépendance hormis `game`, `{n}`/balises/`\n` conservés, vocabulaire du jeu de base, JSON strict.
Ne jamais reprendre les traductions d'autres packs sans l'accord écrit de leurs auteurs.

## Pièges connus

- Le jeu rejette **tout** un fichier de langue au moindre défaut JSON (`Failed to load language
  file`, sans nommer le fichier ; seule la clé citée par l'exception l'identifie). `vs-audit` lit
  les lang des mods de façon tolérante et compte quand même ces clés comme traduites.
- wildcraftfruit 1.5.0 : son `assets/wildcraftfruit/lang/fr.json` a un guillemet manquant ligne
  7034 (`…-sugarbeet-insturmentalcase`), le jeu ignore donc tout son français. À signaler à
  l'auteur ; en attendant, ses fruits restent en anglais en jeu (le glossaire de
  `gen/wcfefcompat.json` n'en dépend pas). `vs-test` le signale en avertissement.
- Les messages du serveur sont traduits avec `ServerLanguage: fr` : `vs-test` attend
  `Entering runphase RunGame`, qui ne l'est pas.

## Priorités (voir la note)

1. ~~wcfefcompat~~ : fait, généré par `vs-gen`.
2. ~~Héraldique (heraldry, capes, heraldrybanners, morebanners)~~ : fait, généré par `vs-gen`.
   Ne jamais éditer à la main les fr.json générés : modifier `gen/*.json`.
3. ~~Petits trous des mods déjà traduits~~ (alchemy, bricklayers, em, molds, foodshelves, wool,
   hydrateordiedrate) : fait à la main, un fr.json par mod.
4. ~~Texte suivi~~ : fait. pipeleaf généré par `vs-gen`, orekiwoofsbeehives et betterruins à la
   main (dialogues de marchands sans accord de genre : les marchands existent en homme et en femme).
5. ~~Modèles de joueur~~ (skeletons, vintageskavenrat, koboldrdx) : faits à la main. Les deux clés
   `game:skinpart-*` que vintageskavenrat partage avec koboldrdx sont livrées dans son fichier.

## Publication

1. Remplir la section `## [Non publié]` de `CHANGELOG.md`, arbre git propre.
2. `vs-release <version>` (SemVer). Il pousse et crée la release GitHub : c'est une action
   publique, ne la lancer qu'à la demande de l'utilisateur.
3. Téléverser le zip à la main sur https://mods.vintagestory.at (l'API ModDB n'accepte pas
   d'upload) en renseignant le modid et au moins une version de jeu, sans quoi les outils de mise à
   jour ne trouvent pas le mod.

## À ne pas faire

- Committer `work/` ou `dist/` (ignorés).
- Zipper à la main : toujours `vs-build` (les `\` de Windows cassent le format zip).
- Modifier `mods.json` à la main, sauf le champ `moddb`.
