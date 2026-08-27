# Caddy config equality test
#
# Verifies that the template-based Caddy configuration (post-refactor)
# generates identical output to the previous inline Nix version.
#
# This is a regression test: the refactor should not change any generated
# configuration files. If this test fails, the template files or the
# substitution logic have diverged from the original inline Nix strings.
{ pkgs, lib }:

let
  hostName = "test-host";
  domain = "${hostName}.internal";

  caHtml = builtins.replaceStrings [ "__DOMAIN__" "__HOSTNAME__" ] [ domain hostName ] (
    builtins.readFile ../../modules/caddy/ca.html
  );

  indexHtml = builtins.replaceStrings
    [ "@domain@" "@hostName@" "@portalCards@" ]
    [ domain hostName "" ]
    (builtins.readFile ../../modules/caddy/index.html);

  # --- Old version: inline Nix strings (from HEAD~2, before refactor) ---

  oldCaddyfile = ''
    {
      admin off
      # Listen on the Tailscale interface only, so vhosts are not
      # reachable from the LAN. TAILSCALE_IP is resolved by the launchd
      # script before Caddy starts; if the Tailscale IP ever changes,
      # Caddy must be restarted to rebind.
      default_bind {$TAILSCALE_IP} 127.0.0.1

      # Each host runs its own internal CA under a host-specific CA ID
      # (the host name, not "local"), so the root CN is distinct per
      # machine ("Caddy Local Authority - <host> - <year> ECC Root") and
      # no root is ever shared between hosts. A fresh CA ID also means
      # the storage namespace (pki/authorities/<host>/ and
      # certificates/<host>/) is new, so a previous auto-generated root
      # or cached leaf certs from an older CA are never reused — no
      # manual storage cleanup is required when the CA changes.
      #
      # The intermediate is auto-generated and auto-renewed. A 730d
      # lifetime with renewal_window_ratio 0.3 (renew at 30% remaining,
      # i.e. ~219d) guarantees the intermediate always has at least
      # ~219d of signing lifetime left, so a 180d leaf is never clamped
      # by the issuer's NotAfter (default 0.2 would leave only ~146d).
      pki {
        ca ${hostName} {
          name "Caddy Local Authority - ${hostName}"
          intermediate_lifetime 730d
          renewal_window_ratio 0.3
        }
      }
    }

    # Common snippets
    (internal_tls) {
      tls {
        issuer internal {
          ca ${hostName}
          lifetime 180d
        }
      }

      # Access log, shared by every vhost that imports this snippet so
      # logging config lives in one place rather than each service
      # module's own site block. The query string is dropped entirely
      # (not selectively masked) because Pocket ID's OIDC flow puts
      # authorization codes and state values in query parameters on
      # these same Caddy-fronted URLs; a denylist of "sensitive"
      # parameter names would need to be kept in sync with every
      # OIDC-fronted service added in the future, and a missed one
      # would leak a token into the log. Written under /var/log so the
      # existing host-log convention already scraped by the log
      # collector picks it up with no collector-side change.
      log {
        output file /var/log/caddy-access.log
        format filter {
          wrap json
          fields {
            request>uri regexp \?.* ""
          }
        }
      }
    }

    # Prometheus metrics, loopback-only like every other scraped
    # service's metrics port (see modules/monitoring/prometheus.yml).
    # A dedicated port rather than the admin API, since the admin API
    # is disabled above.
    :9091 {
      bind 127.0.0.1
      metrics
    }

    import /etc/caddy/sites/*.caddy
  '';

  oldSites = {
    "opencloud.caddy" = ''
      https://opencloud.${domain} {
        import internal_tls
        reverse_proxy 127.0.0.1:9200 {
          flush_interval -1
          transport http {
            response_header_timeout 120s
          }
        }
      }
    '';
    "immich.caddy" = ''
      https://immich.${domain} {
        import internal_tls
        reverse_proxy 127.0.0.1:2283
      }
    '';
    "index.caddy" = ''
      https://${domain} {
        import internal_tls
        handle /index {
          header Content-Type "text/html; charset=utf-8"
          respond `${indexHtml}` 200
        }
        handle {
          redir / /index
        }
      }
    '';
    "attic.caddy" = ''
      https://cache.${domain} {
        import internal_tls
        reverse_proxy 127.0.0.1:8081
      }
    '';
    "ca.caddy" = ''
      http://ca.${domain}, https://ca.${domain} {
        import internal_tls
        handle /ca.crt {
          root * /var/lib/caddy
          @caddy_exists file /caddy/pki/authorities/${hostName}/root.der
          rewrite @caddy_exists /caddy/pki/authorities/${hostName}/root.der

          header Content-Type "application/x-x509-ca-cert"
          file_server
        }
        handle {
          header Content-Type "text/html; charset=utf-8"
          respond `${caHtml}` 200
        }
      }
    '';
  };

  # --- New version: template-based substitution ---

  substituteTemplate = template: replacements:
    builtins.replaceStrings (map (r: r.from) replacements) (map (r: r.to) replacements)
      (builtins.readFile template);

  applyTemplate = template: replacements:
    pkgs.writeText "${baseNameOf template}" (substituteTemplate template replacements);

  commonReplacements = [
    { from = "__HOSTNAME__"; to = hostName; }
    { from = "__DOMAIN__"; to = domain; }
  ];

  newCaddyfile = substituteTemplate ../../modules/caddy/Caddyfile.template commonReplacements;

  newSites = {
    "opencloud.caddy" = substituteTemplate ../../modules/caddy/sites/opencloud.caddy.template commonReplacements;
    "immich.caddy" = substituteTemplate ../../modules/caddy/sites/immich.caddy.template commonReplacements;
    "index.caddy" = substituteTemplate ../../modules/caddy/sites/index.caddy.template (commonReplacements ++ [
      { from = "__INDEX_HTML__"; to = indexHtml; }
    ]);
    "attic.caddy" = substituteTemplate ../../modules/caddy/sites/attic.caddy.template commonReplacements;
    "ca.caddy" = substituteTemplate ../../modules/caddy/sites/ca.caddy.template (commonReplacements ++ [
      { from = "__CA_HTML__"; to = caHtml; }
    ]);
  };

  # --- Comparison ---

  comparisons = {
    "Caddyfile" = oldCaddyfile == newCaddyfile;
  } // lib.mapAttrs' (name: _oldValue: {
    name = "sites/${name}";
    value = oldSites.${name} == newSites.${name};
  }) oldSites;

  failedComparisons = lib.filterAttrs (_: v: !v) comparisons;

  allPassed = failedComparisons == {};

in
pkgs.runCommand "caddy-config-equality-test" { } ''
  mkdir -p $out

  ${if allPassed then ''
    echo "✅ All Caddy config comparisons passed." > $out/result
    echo "" >> $out/result
    echo "Compared files:" >> $out/result
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: "echo '  - ${name}' >> $out/result") comparisons)}
    echo "" >> $out/result
    echo "All generated configurations are identical between inline and template versions." >> $out/result
  '' else ''
    echo "❌ Caddy config equality test FAILED." >&2
    echo "" >&2
    echo "Failed comparisons:" >&2
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: "echo '  - ${name}' >&2") failedComparisons)}
    echo "" >&2
    echo "These files differ between the inline and template versions." >&2
    exit 1
  ''}
''
