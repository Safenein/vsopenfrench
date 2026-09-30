{
  pkgs,
  lib,
  config,
  ...
}:

let
  gameVersion = "1.22.7";

  # Serveur dédié officiel : fournit les assets du jeu de base (game/lang/*.json)
  # pour l'audit et un vrai chargeur de mods pour vs-test. Même recette que la
  # dérivation du modpack bihan.
  vsServer = pkgs.stdenv.mkDerivation {
    pname = "vintagestory-server";
    version = gameVersion;
    src = pkgs.fetchzip {
      url = "https://cdn.vintagestory.at/gamefiles/stable/vs_server_linux-x64_${gameVersion}.tar.gz";
      hash = "sha256-kIqaEQkgiQ6NCICHJWyLYqDn7YgxvnqSOe4HHSj68go=";
      stripRoot = false;
    };
    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.autoPatchelfHook
    ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/vintagestory
      cp -r $src/. $out/share/vintagestory/
      chmod -R u+w $out/share/vintagestory
      rm -f $out/share/vintagestory/server.sh $out/share/vintagestory/credits.txt

      # Le runtime emballé doit correspondre au framework demandé par le
      # serveur, sinon dotnet échoue au démarrage sans dire pourquoi.
      want=$(sed -n 's/.*"version": "\([0-9]*\)\..*/\1/p' \
        $out/share/vintagestory/VintagestoryServer.runtimeconfig.json | head -n1)
      have=${lib.versions.major pkgs.dotnet-runtime_10.version}
      if [ "$want" != "$have" ]; then
        echo "vintagestory-server: le serveur vise .NET $want, la dérivation fournit .NET $have" >&2
        exit 1
      fi

      makeWrapper ${lib.getExe pkgs.dotnet-runtime_10} $out/bin/vintagestory-server \
        --add-flags $out/share/vintagestory/VintagestoryServer.dll

      runHook postInstall
    '';
    meta.mainProgram = "vintagestory-server";
  };

  # Modpack de référence, décrit par mods.json (vs-lock-mods). Chaque zip est
  # téléchargé depuis la ModDB puis ré-empaqueté avec des « / » : certains packs
  # sont zippés sous Windows avec des « \ », ce qui enfreint le format zip.
  modsLock = lib.importJSON ./mods.json;
  fetchMod =
    m:
    pkgs.fetchurl {
      name = "${m.modid}_${m.version}.zip";
      inherit (m) url sha256;
    };
  vsMods = pkgs.runCommand "vintagestory-mods-${modsLock.game}" { } ''
    mkdir $out
    ${lib.getExe pkgs.python3} - $out ${lib.concatMapStringsSep " " fetchMod modsLock.mods} <<'EOF'
    import sys, zipfile
    from pathlib import Path

    out = Path(sys.argv[1])
    for src in map(Path, sys.argv[2:]):
        name = src.name.split("-", 1)[1]  # retire le hash du store
        with zipfile.ZipFile(src) as zin, zipfile.ZipFile(out / name, "w", zipfile.ZIP_DEFLATED) as zout:
            seen = set()
            for info in zin.infolist():
                path = info.filename.replace("\\", "/")
                if path.endswith("/") or path in seen:
                    continue
                seen.add(path)
                zout.writestr(path, zin.read(info))
    EOF
  '';

  # Bibliothèque Python commune aux scripts : lecture tolérante des fichiers de
  # langue des mods (le jeu accepte commentaires et virgules finales), résolution
  # des domaines comme le fait le jeu.
  pyLib = ''
    import json, os, re, sys, zipfile
    from collections import defaultdict
    from pathlib import Path

    ROOT = Path(os.environ.get("DEVENV_ROOT") or ".").resolve()
    MODS_DIR = Path(os.environ.get("VS_MODS_DIR") or "${vsMods}")
    GAME_ASSETS = Path(os.environ.get("VS_GAME_ASSETS") or "${vsServer}/share/vintagestory/assets")
    GAME_VERSION = "${gameVersion}"

    ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)+)"\s*:\s*"((?:[^"\\]|\\.)*)"', re.M)
    LANG = re.compile(r"^assets/([^/]+)/lang/(?:(.*)/)?(en|fr)\.json$")
    MODINFO_FIELD = lambda field: re.compile(rf'"{field}"\s*:\s*"([^"]+)"', re.I)

    def entries(raw):
        dec = lambda s: json.loads(f'"{s}"', strict=False)
        return {dec(k): dec(v) for k, v in ENTRY.findall(raw.decode("utf-8-sig", "replace"))}

    def qualify(key, domain):
        return key if ":" in key else f"{domain}:{key}"

    def modinfo(archive):
        text = archive.read("modinfo.json").decode("utf-8-sig")
        return (MODINFO_FIELD("modid").search(text).group(1).lower(),
                MODINFO_FIELD("version").search(text).group(1))

    # Packs de traduction française tiers présents dans le modpack de référence. vsopenfrench vise à
    # couvrir leur périmètre avec ses propres traductions : leurs textes ne comptent pas comme
    # traduits (audit, lint, vs-gen). Ils restent chargés pour comparer la terminologie.
    TRANSLATION_PACKS = {"modtraductionsfr", "vintagestoryfr", "frtraductionmods"}

    def load_modpack():
        """Textes du modpack : anglais par mod, et qui traduit quoi en français (hors packs tiers)."""
        zips = sorted(MODS_DIR.glob("*.zip"))
        archives = {}
        for z in zips:
            archive = zipfile.ZipFile(z)
            archives[modinfo(archive)[0]] = archive
        english = defaultdict(dict)  # modid -> {clé qualifiée: (domaine, clé, texte)}
        french = defaultdict(set)    # clé qualifiée -> {source}
        game_english = {qualify(k, "game"): v for k, v in entries((GAME_ASSETS / "game/lang/en.json").read_bytes()).items()}
        for key in entries((GAME_ASSETS / "game/lang/fr.json").read_bytes()):
            french[qualify(key, "game")].add("jeu de base")
        for modid, archive in archives.items():
            for name in archive.namelist():
                m = LANG.match(name)
                if not m:
                    continue
                domain, sub, lang = m.groups()
                compat = re.match(r"compatibility/([^/]+)", sub or "")
                if compat and compat.group(1).lower() not in archives:
                    continue  # textes de compatibilité d'un mod absent
                for key, text in entries(archive.read(name)).items():
                    if lang == "fr":
                        if modid not in TRANSLATION_PACKS:
                            french[qualify(key, domain)].add(modid)
                    else:
                        english[modid][qualify(key, domain)] = (domain, key, text)
        return english, french, game_english

    # --- ModDB (vs-lock-mods, vs-check-updates) ---

    MODDB_API = "https://mods.vintagestory.at/api"

    def fetch(url):
        import urllib.error, urllib.request
        req = urllib.request.Request(url, headers={"User-Agent": "vsopenfrench"})
        try:
            with urllib.request.urlopen(req) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            return e.read()

    def moddb_api(path):
        return json.loads(fetch(f"{MODDB_API}/{path}"))

    _aliases = None
    def moddb_resolve(modid, moddb):
        """Renvoie (id ModDB, fiche). Repli sur l'urlalias pour les mods mal étiquetés."""
        global _aliases
        data = moddb_api(f"mod/{moddb or modid}")
        if str(data.get("statuscode")) == "200":
            return moddb, data["mod"]
        if _aliases is None:
            _aliases = {m.get("urlalias"): m["modid"] for m in moddb_api("mods")["mods"]}
        if modid not in _aliases:
            sys.exit(f"{modid}: introuvable sur la ModDB ; renseigner \"moddb\" dans mods.json")
        return _aliases[modid], moddb_api(f"mod/{_aliases[modid]}")["mod"]

    def mod_entry(modid, moddb, release, previous):
        """Entrée de mods.json pour une release ; sha256 recalculé si le fichier a changé."""
        import hashlib, urllib.parse
        url = urllib.parse.quote(release["mainfile"], safe=":/?=&+%")
        entry = {"modid": modid, "version": release["modversion"], "fileid": release["fileid"], "url": url}
        if moddb:
            entry["moddb"] = moddb
        if previous.get("fileid") == release["fileid"] and previous.get("sha256"):
            entry["sha256"] = previous["sha256"]
        else:
            entry["sha256"] = hashlib.sha256(fetch(url)).hexdigest()
        return entry

    def repo_lang_files():
        """Fichiers fr.json livrés par ce dépôt, avec leur chemin dans le zip."""
        base = ROOT / "assets"
        return sorted((p, p.relative_to(ROOT).as_posix()) for p in base.rglob("*.json")) if base.is_dir() else []
  '';

  mkPy =
    name: body:
    pkgs.writeScriptBin name ''
      #!${lib.getExe pkgs.python3}
      ${pyLib}
      ${body}
    '';

  lockMods = mkPy "vs-lock-mods" ''
    """(Re)génère mods.json depuis un dossier de zips de mods.

    Usage: vs-lock-mods <dossier des zips> [version du jeu]
    """
    src = Path(sys.argv[1])
    game = sys.argv[2] if len(sys.argv) > 2 else GAME_VERSION
    lock_path = ROOT / "mods.json"
    old = {m["modid"]: m for m in json.loads(lock_path.read_text("utf-8"))["mods"]} if lock_path.exists() else {}

    mods = []
    for z in sorted(src.glob("*.zip")):
        modid, version = modinfo(zipfile.ZipFile(z))
        moddb, mod = moddb_resolve(modid, old.get(modid, {}).get("moddb"))
        release = next((r for r in mod["releases"] if r["modversion"] == version), None)
        if release is None:
            sys.exit(f"{modid}: version {version} absente de la ModDB")
        print(f"{modid} {version}", file=sys.stderr)
        mods.append(mod_entry(modid, moddb, release, old.get(modid, {})))

    lock_path.write_text(json.dumps({"game": game, "mods": mods}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(mods)} mods écrits dans {lock_path}")
  '';

  checkUpdates = mkPy "vs-check-updates" ''
    """Cherche sur la ModDB une version plus récente de chaque mod de mods.json.

    Usage: vs-check-updates [--write] [--markdown FICHIER]
    Retient, pour chaque mod, la release la plus récente dont les tags contiennent la version du
    jeu de mods.json. --write met mods.json à jour (sha256 compris) ; --markdown écrit la liste
    des mises à jour en tableau. Sort en 0 dans tous les cas : c'est vs-audit qui dit s'il y a
    de nouveaux textes.
    """
    args = sys.argv[1:]
    write = "--write" in args
    markdown = Path(args[args.index("--markdown") + 1]) if "--markdown" in args else None

    lock_path = ROOT / "mods.json"
    lock = json.loads(lock_path.read_text("utf-8"))
    game = lock["game"]
    updates, mods = [], []
    for old in lock["mods"]:
        moddb, mod = moddb_resolve(old["modid"], old.get("moddb"))
        release = next((r for r in mod["releases"] if game in r.get("tags", [])), None)
        if release is None or release["fileid"] == old["fileid"]:
            mods.append(old)
            continue
        page = f"https://mods.vintagestory.at/show/mod/{mod['assetid']}"
        updates.append((old["modid"], old["version"], release["modversion"], page))
        print(f"{old['modid']} : {old['version']} -> {release['modversion']}")
        mods.append(mod_entry(old["modid"], moddb, release, {}) if write else old)

    print(f"{len(updates)} mise(s) à jour pour le jeu {game}")
    if write and updates:
        lock_path.write_text(json.dumps({"game": game, "mods": mods}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if markdown:
        lines = [f"Nouvelles versions pour le jeu {game} : {len(updates)}.", ""]
        if updates:
            lines += ["| Mod | Référence | Nouvelle version |", "| --- | --- | --- |"]
            lines += [f"| [`{m}`]({page}) | {a} | {b} |" for m, a, b, page in updates]
        markdown.write_text("\n".join(lines) + "\n", encoding="utf-8")
  '';

  audit = mkPy "vs-audit" ''
    """Liste les textes anglais du modpack sans traduction française.

    Usage: vs-audit [dossier de sortie, défaut work/todo]
    Écrit un <modid>.json par mod, par domaine : traduire les valeurs donne un fr.json.
    Les fr.json de ce dépôt comptent comme traduits.
    """
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "work/todo"
    english, french, _ = load_modpack()
    for path, rel in repo_lang_files():
        m = LANG.match(rel)
        if m and m.group(3) == "fr":
            for key in entries(path.read_bytes()):
                french[qualify(key, m.group(1))].add("vsopenfrench")

    out.mkdir(parents=True, exist_ok=True)
    for stale in out.glob("*.json"):
        stale.unlink()
    total = mods = 0
    for modid, keys in sorted(english.items()):
        todo = defaultdict(dict)
        for qkey, (domain, key, text) in keys.items():
            if qkey not in french and text.strip():
                todo[domain][key] = text
        if todo:
            missing = sum(len(v) for v in todo.values())
            total, mods = total + missing, mods + 1
            print(f"{modid}: {missing}/{len(keys)} clé(s) sans français")
            (out / f"{modid}.json").write_text(json.dumps(todo, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Total : {total} clé(s) dans {mods} mod(s) -> {out}")
  '';

  gen = mkPy "vs-gen" ''
    """Génère les fr.json des mods traduits par gabarits, depuis gen/*.json.

    Usage: vs-gen [--check]
    - gen/wcfefcompat.json -> assets/wcfefcompat : chaque clé prend sa valeur dans « cles »,
      sinon dans le premier gabarit de son type dont la regex « en » correspond au texte anglais,
      avec le nom français du code tiré de la table du gabarit (« fruits » par défaut).
    - gen/expandedfoods.json -> assets/expandedfoods : tartes mixtes décomposées par motifs (« A/B pie »)
      et glossaire des ingrédients, noms spéciaux, légumes émincés, « cles ».
    - gen/pipeleaf.json -> assets/pipeleaf : mélanges de deux plantes, formes à fumer, pipes par
      métal, descriptions par paire de plantes, et « cles » (clés qualifiées).
    - gen/heraldique.json -> heraldry, capes, heraldrybanners, morebanners : motif × couleur
      accordée, objets × couleur, et « cles » (clés qualifiées). Une clé déclarée par plusieurs de
      ces mods va dans le fichier de son domaine (assets/heraldry), les autres dans celui du mod.
    Échoue sur toute clé anglaise sans traduction. --check échoue si un fichier livré diffère.
    """
    VOWELS = "aàâeéèêëiîïoôuùûüœ"
    PREPOSITIONS = {"de", "du", "des", "à", "au", "aux", "en"}

    english, french, _ = load_modpack()
    outputs = defaultdict(dict)  # domaine du fichier -> {clé: texte}
    missing = 0

    def todo(modid):
        """Clés anglaises du mod sans français ailleurs : (clé qualifiée, texte)."""
        for qkey, (_, _, text) in english[modid].items():
            if qkey not in french and text.strip():
                yield qkey, text

    placed = set()  # clés qualifiées déjà livrées : une clé déclarée par plusieurs mods ne sort qu'une fois

    def put(domain, qkey, value):
        if qkey in placed:
            return
        placed.add(qkey)
        key_domain, key = qkey.split(":", 1)
        outputs[domain][key if key_domain == domain else qkey] = value

    def miss(qkey, error, text):
        global missing
        missing += 1
        print(f"{qkey}: {error} : {text}", file=sys.stderr)

    def plural_word(word):
        if word[-1] in "sxz":
            return word
        return word + ("x" if word.endswith(("eau", "eu")) else "s")

    def plural(name):
        """Met au pluriel les mots qui précèdent le premier complément : « baies de sureau noir »."""
        words = name.split(" ")
        for i, word in enumerate(words):
            if word in PREPOSITIONS or word.startswith("d'"):
                return " ".join(words)
            words[i] = "-".join(plural_word(part) for part in word.split("-"))
        return " ".join(words)

    def same_case(text, model):
        first = text[0].upper() if model[0].isupper() else text[0].lower()
        return first + text[1:]

    # --- wcfefcompat : produits × fruits ---

    wcfef = json.loads((ROOT / "gen/wcfefcompat.json").read_text("utf-8"))
    types = "|".join(sorted(map(re.escape, wcfef["gabarits"]), key=len, reverse=True))
    states = "|".join(wcfef["etats"])
    PIE = re.compile(rf"^pie-single-wcfefcompat:({types})-(.+)-({states})$")
    ITEM = re.compile(
        rf"^(?:incontainer-item-|game:recipeingredient-item-|recipeingredient-item-|item-"
        rf"|game:meal-ingredient-yogurtmeal-primary-yogurt-)({types})-(.+?)(?:-insturmentalcase)?$"
    )

    def fruit_fields(entry):
        name, fem = entry["fr"], entry["genre"] == "f"
        many = entry.get("nombre") == "pluriel"
        elide = entry.get("elision", name[0].lower() in VOWELS)
        if many:
            article = "aux "
        elif elide:
            article = "à l'"
        else:
            article = "à la " if fem else "au "
        return {
            "nom": name,
            "pl": entry.get("pluriel", name if many else plural(name)),
            "de": ("d'" if elide else "de ") + name,
            "a": article + name,
            "e": "e" if fem else "",
            "s": "s" if many else "",
        }

    def translate_wcfef(key, text):
        if key in wcfef["cles"]:
            return wcfef["cles"][key], None
        state = ""
        m = PIE.match(key)
        if m:
            kind, code, state = m.group(1), m.group(2), m.group(3)
            form = "tarte"
        elif m := ITEM.match(key):
            kind, code = m.groups()
            form = "objet"
        else:
            return None, "aucun gabarit pour cette clé"
        for rule in wcfef["gabarits"][kind].get(form, []):
            if re.search(rule["en"], text, re.I):
                table = rule.get("table", "fruits")
                entry = wcfef["tables"][table].get(code)
                if entry is None:
                    return None, f"code « {code} » absent de la table « {table} »"
                value = rule["fr"].format(etat=wcfef["etats"].get(state, ""), **fruit_fields(entry))
                return same_case(value, text), None
        return None, f"texte anglais hors gabarit ({kind}, {form})"

    for qkey, text in todo("wcfefcompat"):
        value, error = translate_wcfef(qkey.split(":", 1)[1] if qkey.startswith("wcfefcompat:") else qkey, text)
        if error:
            miss(qkey, error, text)
        else:
            put("wcfefcompat", qkey, value)

    # --- héraldique : motifs × couleurs ---

    heraldry = json.loads((ROOT / "gen/heraldique.json").read_text("utf-8"))
    colors = heraldry["couleurs"]
    COLOR = "|".join(colors)
    PATTERN = re.compile(rf"^heraldry:pattern-(.+)_({COLOR})$")
    HERALDRY_MODS = ["heraldry", "capes", "heraldrybanners", "morebanners"]

    def color_word(color, entry):
        forms = colors[color]
        word = forms["f"] if entry["genre"] == "f" else forms["m"]
        if entry.get("nombre") == "pluriel" and not forms.get("invariable"):
            word = plural_word(word)
        return word

    def colored(entry, color):
        name = entry["fr"] if "{c}" in entry["fr"] else entry["fr"] + " {c}"
        return name.replace("{c}", color_word(color, entry))

    def translate_heraldry(qkey):
        if qkey in heraldry["cles"]:
            return heraldry["cles"][qkey], None
        if m := PATTERN.match(qkey):
            motif, color = m.groups()
            entry = heraldry["motifs"].get(motif)
            if entry is None:
                return None, f"motif « {motif} » absent de « motifs »"
            return colored(entry, color), None
        for prefix, entry in heraldry["objets"].items():
            color = qkey.removeprefix(prefix)
            if qkey.startswith(prefix) and color in colors:
                return colored(entry, color), None
        return None, "aucun gabarit pour cette clé"

    owners = defaultdict(list)
    for modid in HERALDRY_MODS:
        for qkey, text in todo(modid):
            owners[qkey].append((modid, text))
    for qkey, found in owners.items():
        value, error = translate_heraldry(qkey)
        if error:
            miss(qkey, error, found[0][1])
        else:
            put(qkey.split(":", 1)[0] if len(found) > 1 else found[0][0], qkey, value)

    # --- pipeleaf : mélanges de plantes, pipes par métal ---

    pipeleaf = json.loads((ROOT / "gen/pipeleaf.json").read_text("utf-8"))
    plants, metals, templates = pipeleaf["plantes"], pipeleaf["metaux"], pipeleaf["gabarits"]
    PLANT = "|".join(sorted(plants, key=len, reverse=True))
    METAL = "|".join(sorted(metals, key=len, reverse=True))
    BLEND = re.compile(rf"^pipeleaf:(item|itemdesc)-(?:cured|shag)blend-({PLANT})-({PLANT})$")
    SMOKABLE = re.compile(rf"^pipeleaf:item-smokable-({PLANT})-(cured|shag)$")
    METAL_ITEMS = {
        "pipe": re.compile(rf"^pipeleaf:item-smokingpipe-briarburl-({METAL})$"),
        "tuyau": re.compile(rf"^pipeleaf:item-smokingpipestem-({METAL})$"),
        "briquet": re.compile(rf"^pipeleaf:item-pipelighter-({METAL})$"),
    }

    def of(name):
        name = name[0].lower() + name[1:]
        return ("d'" if name[0] in VOWELS + "h" else "de ") + name

    def translate_pipeleaf(qkey):
        if qkey in pipeleaf["cles"]:
            return pipeleaf["cles"][qkey], None
        if m := BLEND.match(qkey):
            kind, a, b = m.groups()
            if kind == "item":
                return templates["melange"].format(de_a=of(plants[a]), de_b=of(plants[b])), None
            pair = "+".join(sorted((a, b)))
            if pair in pipeleaf["descriptions"]:
                return pipeleaf["descriptions"][pair], None
            return None, f"description « {pair} » absente de « descriptions »"
        if m := SMOKABLE.match(qkey):
            return templates["fumable"][m.group(2)].format(nom=plants[m.group(1)]), None
        for name, pattern in METAL_ITEMS.items():
            if m := pattern.match(qkey):
                return templates[name].format(metal=metals[m.group(1)]), None
        return None, "aucun gabarit pour cette clé"

    for qkey, text in todo("pipeleaf"):
        value, error = translate_pipeleaf(qkey)
        if error:
            miss(qkey, error, text)
        else:
            put("pipeleaf", qkey, value)

    # --- expandedfoods : tartes mixtes (« A/B pie ») et légumes émincés ---

    expanded = json.loads((ROOT / "gen/expandedfoods.json").read_text("utf-8"))
    PIE_EF = re.compile(r"^game:pie-(?:single|mixed)-.+-(raw|partbaked|perfect|charred)$")
    CHOPPED = re.compile(r"^(?:game:)?recipeingredient-item-cookedchoppedvegetable-(.+)-\*(?:-insturmentalcase)?$")
    STATE_EN = re.compile(r"\s*\((?:raw|part-baked|charred)\)$")

    def pie_name(stem):
        if stem in expanded["noms"]:
            return expanded["noms"][stem]
        ingredients = expanded["ingredients"]
        for rule in expanded["motifs"]:
            m = re.match(rule["en"], stem)
            if not m:
                continue
            parts = {name: ingredients.get(text.lower() + rule.get("suffixe", "")) for name, text in m.groupdict().items()}
            if None in parts.values():
                continue
            kind = "tourte" if any(p.get("tourte") for p in parts.values()) else "tarte"
            return rule["fr"].format(tarte=expanded["tartes"][kind], **{n: p["fr"] for n, p in parts.items()})
        return None

    def translate_expanded(qkey, text):
        key = qkey.split(":", 1)[1] if qkey.startswith("expandedfoods:") else qkey
        if key in expanded["cles"]:
            return expanded["cles"][key], None
        if text in expanded.get("textes", {}):
            return expanded["textes"][text], None
        if m := CHOPPED.match(key):
            if m.group(1) in expanded["emince"]:
                return expanded["emince"][m.group(1)], None
            return None, f"légume « {m.group(1)} » absent de « emince »"
        if m := PIE_EF.match(key):
            name = pie_name(STATE_EN.sub("", text))
            if name is None:
                return None, "nom de tarte hors motifs et hors « noms »"
            return name + expanded["etats"][m.group(1)], None
        return None, "aucun gabarit pour cette clé"

    for qkey, text in todo("expandedfoods"):
        value, error = translate_expanded(qkey, text)
        if error:
            miss(qkey, error, text)
        else:
            put("expandedfoods", qkey, value)

    # --- écriture ---

    check = "--check" in sys.argv[1:]
    stale = []
    for domain, values in sorted(outputs.items()):
        out = ROOT / "assets" / domain / "lang/fr.json"
        rendered = json.dumps(values, ensure_ascii=False, indent=2) + "\n"
        if check:
            if not out.exists() or out.read_text("utf-8") != rendered:
                stale.append(out.relative_to(ROOT).as_posix())
        else:
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(rendered, encoding="utf-8")
            print(f"{len(values)} clé(s) écrites dans {out.relative_to(ROOT)}")
    if stale:
        sys.exit("vs-gen : pas à jour, relancer vs-gen : " + ", ".join(stale))
    if missing:
        sys.exit(f"vs-gen : {missing} clé(s) sans traduction")
    if check:
        keys = sum(len(values) for values in outputs.values())
        print(f"vs-gen : {len(outputs)} fichier(s) générés à jour, {keys} clé(s)")
  '';

  lint = mkPy "vs-lint" ''
    """Vérifie les fichiers de langue du dépôt avant livraison.

    Sous GitHub Actions, chaque problème devient aussi une annotation sur la ligne concernée.
    """
    PLACEHOLDER = re.compile(r"\{[^{}]*\}|>>>\w+<<<")
    PLURAL = re.compile(r"\{(p\d+):[^{}]*\}")  # le texte des pluriels {p0:# jour|# jours} se traduit

    def placeholders(text):
        return sorted(PLACEHOLDER.findall(PLURAL.sub(r"{\1}", text)))

    TAG = re.compile(r"</?\s*([a-zA-Z]+)")

    def visible(text):
        """Texte affiché, sans balises ni puces : « <font …>• Archer</font> » -> « Archer »."""
        return re.sub(r"<[^>]*>", "", text).strip(" •\n")

    def tags(text):
        return sorted(t.lower() for t in TAG.findall(PLACEHOLDER.sub("", text)))
    GITHUB = os.environ.get("GITHUB_ACTIONS") == "true"
    counts = {"error": 0, "warning": 0}
    lines = {}  # rel -> lignes du fichier, pour situer les clés

    def line_of(rel, key, last=False):
        needle = re.compile(re.escape(json.dumps(key, ensure_ascii=False)) + r"\s*:")
        found = [i for i, l in enumerate(lines.get(rel, []), 1) if needle.search(l)]
        return (found[-1] if last else found[0]) if found else None

    def report(kind, rel, msg, key=None, line=None):
        counts[kind] += 1
        if line is None and key is not None:
            line = line_of(rel, key)
        where = rel + (f":{line}" if line else "") + (f": {key}" if key else "")
        print(f"{'erreur' if kind == 'error' else 'avertissement'} : {where}: {msg}")
        if GITHUB:
            loc = f"file={rel}" + (f",line={line}" if line else "")
            prefix = f"{key} : " if key else ""
            print(f"::{kind} {loc},title=vs-lint::{prefix}{msg}")

    def strict_load(path, rel):
        raw = path.read_bytes()
        if raw.startswith(b"\xef\xbb\xbf"):
            report("error", rel, "BOM UTF-8 à retirer", line=1)
            raw = raw[3:]
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError as e:
            report("error", rel, f"pas de l'UTF-8 ({e})")
            return {}
        lines[rel] = text.splitlines()
        def pairs(items):
            seen = {}
            for k, v in items:
                if k in seen:
                    report("error", rel, "clé en double", key=k, line=line_of(rel, k, last=True))
                seen[k] = v
            return seen
        try:
            data = json.loads(text, object_pairs_hook=pairs)
        except json.JSONDecodeError as e:
            report("error", rel, f"JSON invalide ({e.msg}, colonne {e.colno})", line=e.lineno)
            return {}
        if not isinstance(data, dict) or not all(isinstance(v, str) for v in data.values()):
            report("error", rel, "attendu un objet {clé: texte}", line=1)
            return {}
        return data

    # Textes qui s'écrivent pareil en français (noms propres, emprunts) : pas d'avertissement.
    same_path = ROOT / "lint/identiques.txt"
    same_in_french = set()
    if same_path.exists():
        for line in same_path.read_text("utf-8").splitlines():
            if line.strip() and not line.startswith("#"):
                same_in_french.add(line.strip().lower())

    files = repo_lang_files()
    if not files:
        print("vs-lint : aucun fichier de langue")
        sys.exit(0)

    english, french, game_english = load_modpack()
    all_english = {qk: (modid, text) for modid, keys in english.items() for qk, (_, _, text) in keys.items()}
    ours = {}
    for path, rel in files:
        m = LANG.match(rel)
        if not m or m.group(3) != "fr":
            report("error", rel, "seuls les assets/<domaine>/lang/**/fr.json sont livrés")
            continue
        for key, value in strict_load(path, rel).items():
            qk = qualify(key, m.group(1))
            if qk in ours:
                report("error", rel, f"déjà livrée dans {ours[qk]}", key)
            ours[qk] = rel
            if qk not in all_english:
                if qk in game_english:
                    report("error", rel, "clé du jeu de base, à signaler à la traduction officielle", key)
                else:
                    report("error", rel, "aucune clé anglaise correspondante dans le modpack", key)
                continue
            if french.get(qk):
                report("error", rel, f"déjà traduite par {', '.join(sorted(french[qk]))}", key)
            source = all_english[qk][1]
            if not value.strip():
                report("error", rel, "valeur vide", key)
            if placeholders(value) != placeholders(source):
                report("error", rel, f"paramètres différents de l'anglais : {source!r}", key)
            if tags(value) != tags(source):
                report("error", rel, f"balises différentes de l'anglais : {source!r}", key)
            if value.count("\n") != source.count("\n"):
                report("warning", rel, "nombre de sauts de ligne différent de l'anglais", key)
            if value == source and len(re.findall(r"[^\W\d_]", visible(value))) > 1 and visible(value).lower() not in same_in_french:
                report("warning", rel, "identique à l'anglais (sinon l'ajouter à lint/identiques.txt)", key)

    print(f"vs-lint : {len(ours)} clé(s), {counts['error']} erreur(s), {counts['warning']} avertissement(s)")
    sys.exit(1 if counts["error"] else 0)
  '';

  build = mkPy "vs-build" ''
    """Construit dist/<modid>_<version>.zip (chemins en « / », horodatage fixe)."""
    info = json.loads((ROOT / "modinfo.json").read_text("utf-8"))
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    out = dist / f"{info['modid']}_{info['version']}.zip"
    files = [ROOT / "modinfo.json", ROOT / "modicon.png"]
    files += sorted(p for p in (ROOT / "assets").rglob("*") if p.is_file() and p.name != ".gitkeep")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for path in files:
            if path.exists():
                entry = zipfile.ZipInfo(path.relative_to(ROOT).as_posix(), date_time=(1980, 1, 1, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                z.writestr(entry, path.read_bytes())
    print(out)
  '';
in
{
  env = {
    VS_GAME_VERSION = gameVersion;
    VS_MODS_DIR = "${vsMods}";
    VS_GAME_ASSETS = "${vsServer}/share/vintagestory/assets";
  };

  packages = [
    pkgs.git
    pkgs.gh
    pkgs.jq
    pkgs.python3
    pkgs.zip
    pkgs.unzip
    pkgs.imagemagick
    pkgs.nixfmt
    vsServer
    lockMods
    checkUpdates
    audit
    gen
    lint
    build
  ];

  scripts = {
    vs-test = {
      description = "Démarre un serveur jetable (modpack + mod, langue fr) et vérifie le chargement.";
      packages = [
        vsServer
        build
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gnused
      ];
      exec = ''
        set -euo pipefail
        zip=$(vs-build)
        root="$DEVENV_ROOT/work/server"
        rm -rf "$root"
        mkdir -p "$root/Mods"
        ln -s "$VS_MODS_DIR"/*.zip "$root/Mods/"
        cp "$zip" "$root/Mods/"
        log="$root/Logs/server-main.log"

        # Le serveur lit « /stop » sur son entrée standard une fois démarré.
        fifo="$root/stdin"
        mkfifo "$fifo"
        vintagestory-server --dataPath "$root" --port 42499 \
          --withconfig "{ ServerLanguage: 'fr' }" <"$fifo" >"$root/stdout.log" 2>&1 &
        pid=$!
        exec 3>"$fifo"

        # Marqueur non traduit (« Dedicated Server now running » l'est en fr).
        ready="Entering runphase RunGame"
        for _ in $(seq 900); do
          grep -q "$ready" "$log" 2>/dev/null && break
          kill -0 $pid 2>/dev/null || break
          sleep 1
        done
        echo "/stop" >&3
        exec 3>&-
        timeout 120 tail --pid=$pid -f /dev/null || kill $pid

        status=0
        if ! grep -q "$ready" "$log"; then
          echo "vs-test : le serveur n'a pas démarré, voir $root/stdout.log et $log" >&2
          status=1
        fi
        if grep -q "Mods, sorted by dependency:.*vsopenfrench" "$log"; then
          echo "vs-test : mod vsopenfrench chargé"
        else
          echo "vs-test : mod vsopenfrench absent de la liste des mods chargés" >&2
          status=1
        fi

        # Le message ne nomme pas le fichier : on l'attribue par la clé citée
        # dans l'exception qui suit (« Path '<clé>' »).
        while read -r key; do
          if grep -rqF "\"$key\"" "$DEVENV_ROOT/assets" 2>/dev/null; then
            echo "vs-test : fr.json refusé par le jeu, clé $key (fichier de ce dépôt)" >&2
            status=1
          else
            echo "vs-test : avertissement, un fr.json d'un autre mod est refusé par le jeu (clé $key)" >&2
          fi
        done < <(grep -A1 "Failed to load language file" "$log" | sed -n "s/.*Path '\([^']*\)'.*/\1/p")

        [ $status -eq 0 ] && echo "vs-test : OK"
        exit $status
      '';
    };

    vs-install = {
      description = "Copie le zip construit dans le dossier Mods du client local.";
      packages = [ build ];
      exec = ''
        set -euo pipefail
        zip=$(vs-build)
        mods="''${VS_CLIENT_MODS:-$HOME/.config/VintagestoryData/Mods}"
        mkdir -p "$mods"
        rm -f "$mods"/vsopenfrench_*.zip
        cp "$zip" "$mods/"
        echo "installé dans $mods"
      '';
    };

    vs-logo = {
      description = "Régénère docs/logo.png (512 px) et modicon.png (128 px).";
      packages = [ pkgs.imagemagick ];
      exec = ''
        set -euo pipefail
        cd "$DEVENV_ROOT"
        # Bulle parchemin sur fond bois, cadre laiton, bande tricolore.
        magick -size 512x512 xc:none \
          -fill '#3a2e22' -stroke '#c9a66b' -strokewidth 14 -draw 'roundrectangle 10,10 501,501 72,72' \
          -stroke none -fill '#efe3c8' \
          -draw 'roundrectangle 64,84 448,356 48,48' -draw 'polygon 132,336 112,444 244,348' \
          -font ${pkgs.libertinus}/share/fonts/opentype/LibertinusSerif-Bold.otf \
          -fill '#3a2e22' -pointsize 200 -gravity north -annotate +0+104 'Fr' \
          -gravity northwest \
          -fill '#1f3a93' -draw 'rectangle 142,290 232,312' \
          -fill '#fbf8f1' -draw 'rectangle 233,290 279,312' \
          -fill '#c8102e' -draw 'rectangle 280,290 370,312' \
          -strip docs/logo.png
        magick docs/logo.png -filter Lanczos -resize 128x128 -strip modicon.png
        echo "docs/logo.png modicon.png"
      '';
    };

    vs-release = {
      description = "Publie une version : modinfo, CHANGELOG, tag git et release GitHub.";
      packages = [
        lint
        build
        pkgs.git
        pkgs.gh
        pkgs.jq
        pkgs.gnused
        pkgs.gawk
      ];
      exec = ''
        set -euo pipefail
        version="''${1:?usage: vs-release <version>}"
        cd "$DEVENV_ROOT"
        if [ -n "$(git status --porcelain)" ]; then
          echo "vs-release : l'arbre git n'est pas propre" >&2
          exit 1
        fi
        if ! grep -q '^## \[Non publié\]' CHANGELOG.md; then
          echo "vs-release : CHANGELOG.md n'a pas de section « ## [Non publié] »" >&2
          exit 1
        fi
        vs-lint

        jq --indent 2 --arg v "$version" '.version = $v' modinfo.json >modinfo.json.tmp
        mv modinfo.json.tmp modinfo.json
        sed -i "s/^## \[Non publié\]/## [Non publié]\n\n## [$version] - $(date +%F)/" CHANGELOG.md
        notes=$(awk -v v="$version" '$0 ~ "^## \\[" v "\\]" {on=1; next} /^## \[/ {on=0} on' CHANGELOG.md)

        zip=$(vs-build)
        git add modinfo.json CHANGELOG.md
        git commit -m "Version $version"
        git tag -a "v$version" -m "Version $version"
        git push --follow-tags
        gh release create "v$version" "$zip" --title "$version" --notes "$notes"

        echo
        echo "Reste à téléverser $zip sur https://mods.vintagestory.at/vsopenfrench"
        echo "(version de jeu ≥ $VS_GAME_VERSION, modid vsopenfrench)."
      '';
    };
  };

  git-hooks.hooks = {
    vs-lint = {
      enable = true;
      name = "vs-lint";
      entry = lib.getExe lint;
      files = "^(assets/.*\\.json|lint/identiques\\.txt)$";
      pass_filenames = false;
    };
    nixfmt.enable = true;
    actionlint.enable = true;
  };

  enterShell = ''
    echo "vsopenfrench — jeu $VS_GAME_VERSION, $(ls "$VS_MODS_DIR" | wc -l) mods de référence"
    echo "  vs-audit     textes sans français -> work/todo/<mod>.json"
    echo "  vs-gen       génère les fr.json traduits par gabarits (gen/*.json)"
    echo "  vs-lint      vérifie assets/**/fr.json"
    echo "  vs-build     construit dist/vsopenfrench_<version>.zip"
    echo "  vs-test      serveur jetable avec le modpack et le mod"
    echo "  vs-install   copie le zip dans le client local"
    echo "  vs-logo      régénère le logo et modicon.png"
    echo "  vs-release   publie une version (tag + release GitHub)"
    echo "  vs-lock-mods régénère mods.json depuis un dossier de zips"
    echo "  vs-check-updates cherche des versions plus récentes des mods (--write : met mods.json à jour)"
  '';

  enterTest = ''
    vs-gen --check
    vs-lint
    python3 -m zipfile -t "$(vs-build)"
  '';
}
