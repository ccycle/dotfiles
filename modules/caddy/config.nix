{ config, lib, pkgs, ... }:

let
  hostName = config.networking.hostName;
  domain = "${hostName}.internal";

  caHtml = builtins.replaceStrings [ "__DOMAIN__" "__HOSTNAME__" ] [ domain hostName ]
    (builtins.readFile ./ca.html);

  sortedEntries = lib.sort (a: b: a.name < b.name) config.services.caddy.portalEntries;

  portalCardsHtml = lib.concatMapStringsSep "\n"
    (entry: ''
      <a href="${entry.url}" class="card">
        <div class="logo">${entry.logoSvg}</div>
        <div class="card-body">
          <h2>${entry.name}</h2>
          <p data-lang="ja">${entry.descriptionJa}</p>
          <p data-lang="en" hidden>${entry.descriptionEn}</p>
        </div>
      </a>
    '')
    sortedEntries;

  indexHtml = builtins.replaceStrings
    [ "@domain@" "@hostName@" "@portalCards@" ]
    [ domain hostName portalCardsHtml ]
    (builtins.readFile ./index.html);

  # Template substitution function
  substituteTemplate = template: replacements:
    builtins.replaceStrings (map (r: r.from) replacements) (map (r: r.to) replacements)
      (builtins.readFile template);

  # Apply substitutions to a template file
  applyTemplate = template: replacements:
    pkgs.writeText "${baseNameOf template}" (substituteTemplate template replacements);

  # Common replacements for all templates
  commonReplacements = [
    { from = "__HOSTNAME__"; to = hostName; }
    { from = "__DOMAIN__"; to = domain; }
  ];

  # Caddyfile
  caddyfile = applyTemplate ./Caddyfile.template commonReplacements;

  # Site configs
  sites = {
    "opencloud.caddy" = applyTemplate ./sites/opencloud.caddy.template commonReplacements;
    "immich.caddy" = applyTemplate ./sites/immich.caddy.template commonReplacements;
    "index.caddy" = applyTemplate ./sites/index.caddy.template (commonReplacements ++ [
      { from = "__INDEX_HTML__"; to = indexHtml; }
    ]);
    "attic.caddy" = applyTemplate ./sites/attic.caddy.template commonReplacements;
    "ca.caddy" = applyTemplate ./sites/ca.caddy.template (commonReplacements ++ [
      { from = "__CA_HTML__"; to = caHtml; }
    ]);
  };
in
{
  # Export the Caddyfile and sites as a derivation
  caddyConfig = pkgs.runCommand "caddy-config" {} ''
    mkdir -p $out/etc/caddy/sites
    cp ${caddyfile} $out/etc/caddy/Caddyfile
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: file: ''
      cp ${file} $out/etc/caddy/sites/${name}
    '') sites)}
  '';
}
