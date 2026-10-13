# Traductions françaises complémentaires (`vsopenfrench`)

<img src="docs/logo.png" alt="Logo" width="128">

Pack de traductions pour [Vintage Story](https://www.vintagestory.at/) qui traduit en français
les textes de mods que les mods eux-mêmes ne traduisent pas. Il couvre aussi, avec ses propres
traductions, le périmètre des packs existants (Pack de Traduction Française, Mod Traductions FR,
French Translation Pack) : il se suffit à lui-même.

- **Aucune dépendance** : le mod ne dépend que du jeu. Une traduction ne sert que si son mod est
  installé, et reste sans effet sinon.
- **Que les trous des mods** : aucune clé déjà traduite par un mod lui-même (ou par le jeu) n'est
  livrée, sauf les quelques surcharges justifiées de [`lint/surcharges.txt`](lint/surcharges.txt)
  (par exemple un trait nommé « Couturier » dans la fiche du personnage et « Drapier » dans les
  recettes). Les packs tiers ci-dessus ne comptent pas : installés avec vsopenfrench, ils sont
  chargés avant lui.
- **Chargé en dernier** : déclaré pack *theme* (sans code ni contenu de jeu), il passe après tous
  les mods, et ses traductions s'affichent même quand un mod livre un fr.json resté en anglais.
- Facultatif des deux côtés : un client peut l'avoir sans le serveur, et inversement.

L'état des lieux qui motive le projet est dans [`docs/audit-2026-09-30.md`](docs/audit-2026-09-30.md).

## Installation

Télécharger le zip depuis la [ModDB](https://mods.vintagestory.at/vsopenfrench) ou les
[releases GitHub](https://github.com/Safenein/vsopenfrench/releases) et le déposer dans le dossier
`Mods` du jeu. Un build de `main` est publié chaque nuit en pré-release
([nightly](https://github.com/Safenein/vsopenfrench/releases/tag/nightly)) quand il a changé.

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

## Remerciements

Une partie des traductions vient d'[Aethernia Translation](https://mods.vintagestory.at/show/mod/64379)
de DiZurix, reprise avec son accord.

## Licence

Traductions sous [CC-BY-4.0](LICENSE). Les textes anglais d'origine appartiennent aux auteurs de
chaque mod.
