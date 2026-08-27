{
  config,
  lib,
  pkgs,
  tailscalePackage,
  ...
}:

let
  hostName = config.networking.hostName;
  domain = "${hostName}.internal";

  caHtml = builtins.replaceStrings [ "__DOMAIN__" "__HOSTNAME__" ] [ domain hostName ] (
    builtins.readFile ./ca.html
  );

  sortedEntries = lib.sort (a: b: a.name < b.name) config.services.caddy.portalEntries;

  portalCardsHtml = lib.concatMapStringsSep "\n" (entry: ''
    <a href="${entry.url}" class="card">
      <div class="logo">${entry.logoSvg}</div>
      <div class="card-body">
        <h2>${entry.name}</h2>
        <p data-lang="ja">${entry.descriptionJa}</p>
        <p data-lang="en" hidden>${entry.descriptionEn}</p>
      </div>
    </a>
  '') sortedEntries;

  indexHtml =
    builtins.replaceStrings
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

  # Hash all Caddy etc entries so the launchd plist changes (and nix-darwin
  # restarts the daemon) whenever any site config is added, removed, or modified.
  caddyEtcHash = builtins.hashString "sha256" (
    lib.concatStrings (
      lib.mapAttrsToList (_: v: v.text or "") (
        lib.filterAttrs (n: _: lib.hasPrefix "caddy/" n) config.environment.etc
      )
    )
  );
in
{
  imports = [
    ./options.nix
  ];

  config = lib.mkIf config.services.caddy.enable {
    services.caddy.portalEntries = [
      {
        name = "CA Certificate";
        url = "https://ca.${domain}";
        descriptionJa = "ルート証明書のダウンロード";
        descriptionEn = "Download Root Certificate";
        logoSvg = builtins.readFile ./ca-certificate-logo.svg;
      }
    ]
    ++ lib.optionals config.services.atticd.enable [
      {
        name = "Attic Cache";
        url = "https://cache.${domain}";
        descriptionJa = "Nix バイナリキャッシュ";
        descriptionEn = "Nix Binary Cache";
        logoSvg = builtins.readFile ./attic-logo.svg;
      }
    ];

    environment.etc = {
      "caddy/Caddyfile".text = builtins.readFile caddyfile;
      "caddy/sites/opencloud.caddy".text = builtins.readFile sites."opencloud.caddy";
      "caddy/sites/immich.caddy".text = builtins.readFile sites."immich.caddy";
      "caddy/sites/index.caddy".text = builtins.readFile sites."index.caddy";
      "caddy/sites/attic.caddy".text = builtins.readFile sites."attic.caddy";
      "caddy/sites/ca.caddy".text = builtins.readFile sites."ca.caddy";
    };

    launchd.daemons.caddy = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/caddy.log";
        StandardErrorPath = "/var/log/caddy.log";
        # Store Caddy data (including the local CA cert) in a predictable location.
        # CA cert will be at /var/lib/caddy/caddy/pki/authorities/${hostName}/root.crt
        # (macOS: Caddy resolves data dirs relative to HOME via ~/Library/Application Support/Caddy/)
        # HOME must be set so Caddy can resolve OS config/cache directories.
        EnvironmentVariables = {
          CADDY_DATA_DIR = "/var/lib/caddy";
          XDG_DATA_HOME = "/var/lib/caddy";
          HOME = "/var/lib/caddy";
        };
      };
      script = ''
        # caddy config hash: ${caddyEtcHash}
        # Wait for Tailscale so default_bind in the Caddyfile can resolve;
        # KeepAlive restarts us until the IP is available.
        until TAILSCALE_IP=$(${tailscalePackage}/bin/tailscale ip -4 2>/dev/null) && [ -n "$TAILSCALE_IP" ]; do
          echo "Waiting for Tailscale..."
          sleep 2
        done
        export TAILSCALE_IP
        echo "Binding Caddy to Tailscale IP: $TAILSCALE_IP"

        mkdir -p /var/lib/caddy
        # Ensure Caddy has permissions to write to its data dir (running as root)
        chmod 755 /var/lib/caddy

        # Convert PEM to DER if the cert already exists (covers restarts)
        PEM="/var/lib/caddy/caddy/pki/authorities/${hostName}/root.crt"
        DER="/var/lib/caddy/caddy/pki/authorities/${hostName}/root.der"
        [ -f "$PEM" ] && ${pkgs.openssl}/bin/openssl x509 -in "$PEM" -outform DER -out "$DER"

        # Background converter for first boot (cert doesn't exist yet)
        (
          for i in $(seq 1 12); do
            [ -f "$PEM" ] && break
            sleep 5
          done
          [ -f "$PEM" ] && [ ! -f "$DER" ] && \
            ${pkgs.openssl}/bin/openssl x509 -in "$PEM" -outform DER -out "$DER"
        ) &

        exec ${pkgs.caddy}/bin/caddy run \
          --config /etc/caddy/Caddyfile \
          --adapter caddyfile
      '';
    };

    # nix's trust of Caddy's internal CA (so binary caches on *.internal are
    # usable) is handled centrally in bootstrap/modules/attic/darwin.nix,
    # covering both this host and every other profile.
  };
}
