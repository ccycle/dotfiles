{ lib, ... }:

let
  catalog = builtins.fromJSON (builtins.readFile ./catalog.json);
  modelEntries = lib.mapAttrsToList (id: m: { inherit id; } // m) catalog.models;

  aliasesForModel = model: {
    "mtplx-start-${model.shortId}" =
      "launchctl kickstart -k gui/$(id -u)/org.nixos.mtplx-${model.shortId}";
    "mtplx-stop-${model.shortId}" =
      "launchctl kill SIGTERM gui/$(id -u)/org.nixos.mtplx-${model.shortId}";
  };
in
{
  programs.zsh.shellAliases = lib.foldl' (acc: model: acc // aliasesForModel model) { } modelEntries;
}
