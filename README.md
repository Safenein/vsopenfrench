# Traductions françaises complémentaires (`vsopenfrench`)

<img src="docs/logo.png" alt="Logo" width="128">

Mod de contenu pour [Vintage Story](https://www.vintagestory.at/) qui traduit en français les
textes de mods que ni les mods eux-mêmes ni les packs existants (Pack de Traduction Française,
Mod Traductions FR, French Translation Pack) ne traduisent.

- **Aucune dépendance** : le mod ne dépend que du jeu. Une traduction ne sert que si son mod est
  installé, et reste sans effet sinon.
- **Que les trous** : chaque clé livrée est absente de tous les autres fichiers `fr.json` du
  modpack de référence. L'ordre de chargement des packs n'a donc pas d'importance.
- Facultatif des deux côtés : un client peut l'avoir sans le serveur, et inversement.

L'état des lieux qui motive le projet est dans [`docs/audit-2026-09-30.md`](docs/audit-2026-09-30.md).

## Installation

Télécharger le zip depuis la [ModDB](https://mods.vintagestory.at/vsopenfrench) ou les
[releases GitHub](https://github.com/Safenein/vsopenfrench/releases) et le déposer dans le dossier
`Mods` du jeu.

## Contribuer

L'environnement se lance avec [devenv](https://devenv.sh) (`devenv shell`, ou direnv). Il fournit
le serveur du jeu, le modpack de référence (`mods.json`) et les commandes :

| Commande | Rôle |
| --- | --- |
| `vs-audit` | écrit dans `work/todo/<mod>.json` les textes anglais encore sans français |
| `vs-lint` | vérifie les `assets/**/fr.json` du dépôt |
| `vs-build` | construit `dist/vsopenfrench_<version>.zip` |
| `vs-test` | démarre un serveur jetable en français avec le modpack et le mod |
| `vs-install` | copie le zip dans le client local |
| `vs-logo` | régénère le logo et `modicon.png` |
| `vs-release <version>` | publie une version (tag, release GitHub) |
| `vs-lock-mods <dossier>` | régénère `mods.json` depuis un dossier de zips |

Traduire : lancer `vs-audit`, reprendre les clés d'un `work/todo/<mod>.json` dans
`assets/<domaine>/lang/fr.json`, traduire les valeurs, puis `vs-lint`.

## Licence

Traductions sous [CC-BY-4.0](LICENSE). Les textes anglais d'origine appartiennent aux auteurs de
chaque mod.
