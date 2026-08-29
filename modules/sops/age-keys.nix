# Single source of truth for per-machine age keys and their recipient
# mapping. The committed .sops.yaml is generated from this file by
# scripts/sops/generate-sops-yaml.sh; scripts/sops/check-recipients.sh
# verifies that every secrets file's actual recipients match the rules
# declared here (enforced by the verify-change skill).
#
# Model:
#   - One age key per machine, installed at ~/.config/sops/age/keys.txt.
#     Which key a machine uses is identified by its content; Nix does not
#     need to detect the host.
#   - A secrets file is encrypted only to the keys of the hosts that
#     actually consume it (per-module recipient sets). A leaked key on one
#     host therefore cannot decrypt another host's secrets.
{
  # hostName -> age public key (the key in that machine's keys.txt).
  # "private" is the key shared by all workstations (private profile).
  hosts = {
    mac-mini-m4 = "age15z4jwrurefasz3qulmhuygnrjvqmpenf9l9dv4ese8vx6hq3rg6qw8s950";
    mac-mini-m4-pro = "age1fwsg098n3t7n7vh0sf6fey6r7r2nkewl0eksk3t3d3g8sh75rv4s8xe42k";
    private = "age16fu8k22snemzhljtrg7puedvypww5pv9uauutv4ckuns783fd9ds5perdr";
  };

  # Keys kept as recipients during the two-phase migration only. Every
  # secrets file is re-encrypted with the old key + the new per-machine
  # keys; once every machine's keys.txt has been swapped, empty this list,
  # regenerate .sops.yaml, and run updatekeys to drop the old key.
  # The recipient check fails until no file carries a key outside its rule.
  transitionKeys = [ ];

  # path_regex -> host names whose keys must be able to decrypt matching files.
  # Rules are evaluated in order; the first match wins (sops semantics).
  rules = [
    {
      path_regex = "bootstrap/modules/.*secrets.yaml$";
      hosts = [
        "private"
        "mac-mini-m4"
        "mac-mini-m4-pro"
      ];
    }
    {
      path_regex = "modules/tailscale/secrets.yaml$";
      hosts = [
        "mac-mini-m4"
        "mac-mini-m4-pro"
      ];
    }
    {
      # Per-host secret files for services running on both servers.
      path_regex = "modules/(immich|monitoring|opencloud|pocket-id)/secrets-mac-mini-m4.yaml$";
      hosts = [ "mac-mini-m4" ];
    }
    {
      path_regex = "modules/(immich|monitoring|opencloud|pocket-id|static-reports|opencode-web|pi-web)/secrets-mac-mini-m4-pro.yaml$";
      hosts = [ "mac-mini-m4-pro" ];
    }
    {
      # Server-side services running exclusively on mac-mini-m4-pro.
      path_regex = "modules/(attic|forgejo|gitlab)/secrets.yaml$";
      hosts = [ "mac-mini-m4-pro" ];
    }
  ];
}
