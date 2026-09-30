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

    def load_modpack():
        """Textes du modpack : anglais par mod, et qui traduit quoi en français."""
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
                        french[qualify(key, domain)].add(modid)
                    else:
                        english[modid][qualify(key, domain)] = (domain, key, text)
        return english, french, game_english

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
    import hashlib, urllib.parse, urllib.request

    API = "https://mods.vintagestory.at/api"

    def fetch(url):
        req = urllib.request.Request(url, headers={"User-Agent": "vsopenfrench/vs-lock-mods"})
        try:
            with urllib.request.urlopen(req) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            return e.read()

    def api(path):
        return json.loads(fetch(f"{API}/{path}"))

    aliases = None
    def resolve(modid, moddb):
        """Renvoie (id ModDB, fiche). Repli sur l'urlalias pour les mods mal étiquetés."""
        global aliases
        data = api(f"mod/{moddb or modid}")
        if str(data.get("statuscode")) == "200":
            return moddb, data["mod"]
        if aliases is None:
            aliases = {m.get("urlalias"): m["modid"] for m in api("mods")["mods"]}
        if modid not in aliases:
            sys.exit(f"{modid}: introuvable sur la ModDB ; renseigner \"moddb\" dans mods.json")
        return aliases[modid], api(f"mod/{aliases[modid]}")["mod"]

    src = Path(sys.argv[1])
    game = sys.argv[2] if len(sys.argv) > 2 else GAME_VERSION
    lock_path = ROOT / "mods.json"
    old = {m["modid"]: m for m in json.loads(lock_path.read_text("utf-8"))["mods"]} if lock_path.exists() else {}

    mods = []
    for z in sorted(src.glob("*.zip")):
        modid, version = modinfo(zipfile.ZipFile(z))
        moddb, mod = resolve(modid, old.get(modid, {}).get("moddb"))
        release = next((r for r in mod["releases"] if r["modversion"] == version), None)
        if release is None:
            sys.exit(f"{modid}: version {version} absente de la ModDB")
        url = urllib.parse.quote(release["mainfile"], safe=":/?=&+%")
        entry = {"modid": modid, "version": version, "fileid": release["fileid"], "url": url}
        if moddb:
            entry["moddb"] = moddb
        prev = old.get(modid, {})
        if prev.get("fileid") == release["fileid"] and prev.get("sha256"):
            entry["sha256"] = prev["sha256"]
        else:
            entry["sha256"] = hashlib.sha256(fetch(url)).hexdigest()
        print(f"{modid} {version}", file=sys.stderr)
        mods.append(entry)

    lock_path.write_text(json.dumps({"game": game, "mods": mods}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(mods)} mods écrits dans {lock_path}")
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

  lint = mkPy "vs-lint" ''
    """Vérifie les fichiers de langue du dépôt avant livraison.

    Sous GitHub Actions, chaque problème devient aussi une annotation sur la ligne concernée.
    """
    PLACEHOLDER = re.compile(r"\{[^{}]*\}")
    TAG = re.compile(r"</?\s*([a-zA-Z]+)")
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
            if sorted(PLACEHOLDER.findall(value)) != sorted(PLACEHOLDER.findall(source)):
                report("error", rel, f"paramètres différents de l'anglais : {source!r}", key)
            if sorted(t.lower() for t in TAG.findall(value)) != sorted(t.lower() for t in TAG.findall(source)):
                report("error", rel, f"balises différentes de l'anglais : {source!r}", key)
            if value.count("\n") != source.count("\n"):
                report("warning", rel, "nombre de sauts de ligne différent de l'anglais", key)
            if value == source:
                report("warning", rel, "identique à l'anglais", key)

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
    audit
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
      files = "^assets/.*\\.json$";
      pass_filenames = false;
    };
    nixfmt.enable = true;
    actionlint.enable = true;
  };

  enterShell = ''
    echo "vsopenfrench — jeu $VS_GAME_VERSION, $(ls "$VS_MODS_DIR" | wc -l) mods de référence"
    echo "  vs-audit     textes sans français -> work/todo/<mod>.json"
    echo "  vs-lint      vérifie assets/**/fr.json"
    echo "  vs-build     construit dist/vsopenfrench_<version>.zip"
    echo "  vs-test      serveur jetable avec le modpack et le mod"
    echo "  vs-install   copie le zip dans le client local"
    echo "  vs-logo      régénère le logo et modicon.png"
    echo "  vs-release   publie une version (tag + release GitHub)"
    echo "  vs-lock-mods régénère mods.json depuis un dossier de zips"
  '';

  enterTest = ''
    vs-lint
    python3 -m zipfile -t "$(vs-build)"
  '';
}
