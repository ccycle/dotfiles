# Package by Feature structure validator (pure Nix, builtins only).
#
# Rules are declared in rules.nix; this file only implements the checks.
# Canonical prose spec: skills/project/nix-module/references/conventions.md
#
# Usage (from the repo root):
#   nix eval --json --impure \
#     --expr 'import ./scripts/package-by-feature/check.nix { repoRoot = ./.; }'
#
# Evaluates to { ok, count, violations = [ { rule, file, message } ... ]; }.
#
# References are extracted lexically: comment-stripped lines are scanned for
# relative path literals ending in .nix, so commented-out imports are ignored
# and no Nix evaluation of the modules themselves takes place.
{ repoRoot
, rules ? import ./rules.nix
}:
let
  inherit (builtins)
    attrNames
    baseNameOf
    concatMap
    concatStringsSep
    dirOf
    elem
    elemAt
    filter
    foldl'
    genList
    isList
    isString
    length
    listToAttrs
    pathExists
    readDir
    readFile
    split
    stringLength
    substring
    ;

  hasPrefix = pre: s: substring 0 (stringLength pre) s == pre;
  hasSuffix = suf: s:
    let
      sl = stringLength s;
      fl = stringLength suf;
    in
    sl >= fl && substring (sl - fl) fl s == suf;
  init = l: genList (elemAt l) (length l - 1);
  any' = f: foldl' (a: x: a || f x) false;

  isExempt = p: any' (e: p == e || hasPrefix (e + "/") p) rules.exemptPaths;
  isHostModule = p: any' (h: p == h || hasPrefix (h + "/") p) rules.hostModules;

  abs = rel: repoRoot + ("/" + rel);

  # Recursively list all entries under a repo-relative directory.
  walk = rel:
    let
      entries = readDir (abs rel);
    in
    concatMap
      (name:
        let
          p = "${rel}/${name}";
        in
        if entries.${name} == "directory"
        then [{ path = p; type = "directory"; }] ++ walk p
        else [{ path = p; type = entries.${name}; }])
      (attrNames entries);

  allEntries = concatMap walk rules.roots;
  allDirs =
    rules.roots
    ++ map (e: e.path)
      (filter (e: e.type == "directory" && !isExempt e.path) allEntries);
  nixFilePaths = map (e: e.path)
    (filter
      (e: e.type == "regular" && hasSuffix ".nix" e.path && !isExempt e.path)
      allEntries);

  # --- lexical reference extraction ---

  lines = text: filter isString (split "\n" text);
  stripComment = line: elemAt (split "#" line) 0;
  refRegex = "(\\.\\.?/[A-Za-z0-9_@+./-]*\\.nix)";
  refsInLine = line: map (m: elemAt m 0) (filter isList (split refRegex line));

  splitSlash = s: filter (c: isString c && c != "" && c != ".") (split "/" s);

  # Resolve a relative reference against the referencing file's directory.
  # Returns a repo-relative path, or null when the reference escapes the
  # repository root.
  resolve = dir: ref:
    let
      step = acc: c:
        if acc == null then null
        else if c == ".." then (if acc == [ ] then null else init acc)
        else acc ++ [ c ];
      comps = foldl' step (splitSlash dir) (splitSlash ref);
    in
    if comps == null then null else concatStringsSep "/" comps;

  refsByFile = listToAttrs (map
    (p: {
      name = p;
      value = map (r: { raw = r; resolved = resolve (dirOf p) r; })
        (concatMap (l: refsInLine (stripComment l)) (lines (readFile (abs p))));
    })
    nixFilePaths);

  refsOf = p: refsByFile.${p} or [ ];
  resolvedRefsOf = p: filter (r: r != null) (map (r: r.resolved) (refsOf p));

  mkV = rule: file: message: { inherit rule file message; };

  # --- rule: flat-submodule (conventions.md §1, §5) ---
  # Every .nix file must be an aggregation file or a whitelisted support file.

  allowedNames = rules.aggregationFiles ++ rules.supportFiles;
  flatSubmodule = map
    (p: mkV "flat-submodule" p
      "unexpected .nix file; only ${toString allowedNames} are allowed — sub-modules must be directories (conventions.md §5)")
    (filter (p: !(elem (baseNameOf p) allowedNames)) nixFilePaths);

  # --- rule: aggregation-missing-import (conventions.md §3) ---
  # Every child directory containing an aggregation file must be imported by
  # the parent's same-platform aggregator. Exceptions: host modules (imported
  # by flake.nix), allowUnimported entries, and a child home.nix pulled in by
  # its own darwin.nix via home-manager.sharedModules (conventions.md §8).

  childDirsOf = d:
    let
      entries = readDir (abs d);
    in
    filter (c: !isExempt c)
      (map (n: "${d}/${n}")
        (filter (n: entries.${n} == "directory") (attrNames entries)));

  aggregationMissingImport = concatMap
    (d: concatMap
      (c:
        if isHostModule c || elem c rules.allowUnimported then [ ]
        else
          concatMap
            (aggFile:
              let
                childAgg = "${c}/${aggFile}";
                parentAgg = "${d}/${aggFile}";
                sharedModulesOk =
                  aggFile == "home.nix"
                  && elem childAgg (resolvedRefsOf "${c}/darwin.nix");
              in
              if !pathExists (abs childAgg) || sharedModulesOk then [ ]
              else if !pathExists (abs parentAgg) then
                [
                  (mkV "aggregation-missing-import" parentAgg
                    "aggregator missing: ${childAgg} exists but ${parentAgg} does not (conventions.md §3)")
                ]
              else if !elem childAgg (resolvedRefsOf parentAgg) then
                [
                  (mkV "aggregation-missing-import" parentAgg
                    "does not import ./${baseNameOf c}/${aggFile}; add the import or list ${c} in allowUnimported (conventions.md §3)")
                ]
              else [ ])
            rules.aggregationFiles)
      (childDirsOf d))
    allDirs;

  # --- rule: import-unresolved (conventions.md §3) ---

  importUnresolved = concatMap
    (p: concatMap
      (r:
        if r.resolved == null then
          [ (mkV "import-unresolved" p "reference ${r.raw} escapes the repository root") ]
        else if !pathExists (abs r.resolved) then
          [ (mkV "import-unresolved" p "reference ${r.raw} -> ${r.resolved} does not exist") ]
        else [ ])
      (refsOf p))
    nixFilePaths;

  # --- rule: grandchild-import (conventions.md §3) ---
  # ./-references may reach at most one directory level deep; never import a
  # grandchild directly when a child aggregation file exists.

  grandchildImport = concatMap
    (p: concatMap
      (r:
        if hasPrefix "../" r.raw || length (splitSlash r.raw) <= 2 then [ ]
        else
          [
            (mkV "grandchild-import" p
              "reference ${r.raw} reaches deeper than one directory level (conventions.md §3)")
          ])
      (refsOf p))
    nixFilePaths;

  # --- rule: cross-hierarchy-import (conventions.md §3) ---
  # ../-references may only target crossHierarchyAllowed directories.

  crossHierarchyImport = concatMap
    (p: concatMap
      (r:
        let
          allowed = any'
            (a: r.resolved == a || hasPrefix (a + "/") r.resolved)
            rules.crossHierarchyAllowed;
        in
        if !hasPrefix "../" r.raw || r.resolved == null || allowed then [ ]
        else
          [
            (mkV "cross-hierarchy-import" p
              "reference ${r.raw} crosses feature hierarchies; only ${toString rules.crossHierarchyAllowed} may be referenced with ../ (conventions.md §3)")
          ])
      (refsOf p))
    nixFilePaths;

  # --- rule: platform-mismatch (conventions.md §2, §8) ---
  # home.nix never references darwin config. darwin.nix may reference home
  # config only as ./home.nix (the home-manager.sharedModules pattern).

  platformMismatch = concatMap
    (p:
      let
        base = baseNameOf p;
      in
      if base == "home.nix" then
        map
          (r: mkV "platform-mismatch" p
            "home.nix must not reference darwin config ${r.raw} (conventions.md §2)")
          (filter (r: baseNameOf r.raw == "darwin.nix") (refsOf p))
      else if base == "darwin.nix" then
        map
          (r: mkV "platform-mismatch" p
            "darwin.nix may only reference home config as ./home.nix via home-manager.sharedModules, not ${r.raw} (conventions.md §8)")
          (filter (r: baseNameOf r.raw == "home.nix" && r.raw != "./home.nix")
            (refsOf p))
      else [ ])
    nixFilePaths;

  # --- rule: host-module-imports (conventions.md §6) ---
  # Host profile modules only set option values; they never import features.

  hostModuleImports = concatMap
    (p:
      if !isHostModule p then [ ]
      else
        map
          (r: mkV "host-module-imports" p
            "host modules may only set option values, not import ${r.raw} (conventions.md §6)")
          (filter (r: elem (baseNameOf r.raw) rules.aggregationFiles) (refsOf p)))
    nixFilePaths;

  violations =
    flatSubmodule
    ++ aggregationMissingImport
    ++ importUnresolved
    ++ grandchildImport
    ++ crossHierarchyImport
    ++ platformMismatch
    ++ hostModuleImports;
in
{
  ok = violations == [ ];
  count = length violations;
  inherit violations;
}
