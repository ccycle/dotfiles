{ config, lib, pkgs, ... }:

let
  atticHost = "mac-mini-m4-pro";
  isAtticHost = config.networking.hostName == atticHost;
in
{
  # Attic substituter configuration for all machines.
  #
  # After init.sh has been run and atticd is serving on mac-mini-m4-pro,
  # fill in the public key below:
  #
  #   ssh mac-mini-m4-pro -- attic cache info dotfiles
  #
  nix.settings = {
    extra-substituters = [ "https://cache.${atticHost}.internal/dotfiles" ];
    trusted-public-keys = [ "dotfiles:eSuMT01k8I8jf04ngslFkwCE9KnbKlOTlNosysL/WBA=" ];
    ssl-cert-file = lib.mkForce "/etc/nix/ca-bundle.crt";
  };

  # The cache above is served over Caddy's self-signed "tls internal" CA,
  # which is generated independently per host. On mac-mini-m4-pro itself
  # that CA is already on disk; every other machine has to fetch it from
  # the portal Caddy exposes for exactly this purpose. Either way nix (which
  # uses its own OpenSSL bundle, not the system trust store) needs it merged
  # into a bundle it trusts, layered on top of the keychain-derived
  # /etc/nix/ca_cert.pem from bootstrap/modules/system/darwin.nix.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    set -eu
    mkdir -p /etc/nix
    ATTIC_CA="/etc/nix/attic-ca.crt"
    rebuild_bundle() {
      rm -f /etc/nix/ca-bundle.crt
      if [ -f /etc/nix/ca_cert.pem ]; then
        cat /etc/nix/ca_cert.pem > /etc/nix/ca-bundle.crt
      else
        cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt > /etc/nix/ca-bundle.crt
      fi
      if [ -f "$ATTIC_CA" ]; then
        cat "$ATTIC_CA" >> /etc/nix/ca-bundle.crt
      fi
    }
    ${if isAtticHost then ''
      # Caddy stores each host's CA under pki/authorities/<hostName>/, since
      # each host runs its own internal CA under a host-specific CA ID (see
      # modules/caddy/darwin.nix).
      LOCAL_CA="/var/lib/caddy/caddy/pki/authorities/${config.networking.hostName}/root.crt"
      [ -f "$LOCAL_CA" ] && cp "$LOCAL_CA" "$ATTIC_CA"
      rebuild_bundle
      ( for _ in $(seq 1 24); do
          [ -f "$LOCAL_CA" ] && { cp "$LOCAL_CA" "$ATTIC_CA"; rebuild_bundle; break; }
          sleep 5
        done ) &
    '' else ''
      rebuild_bundle
      ( for _ in $(seq 1 24); do
          curl -fsSL --max-time 5 "http://ca.${atticHost}.internal/ca.crt" -o "$ATTIC_CA" 2>/dev/null \
            && ${pkgs.openssl}/bin/openssl x509 -inform DER -in "$ATTIC_CA" -out "$ATTIC_CA.tmp" 2>/dev/null \
            && mv "$ATTIC_CA.tmp" "$ATTIC_CA" \
            && { rebuild_bundle; break; }
          sleep 5
        done ) &
    ''}
  '';
}
