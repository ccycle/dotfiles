# Non-fatal check: warns at eval time (visible in `darwin-rebuild switch`
# output) if a configured storage volume path doesn't currently exist.
#
# This is deliberately a warning, not an assertion. `pathExists` can't tell
# a typo (permanently wrong path) apart from a removable volume that simply
# isn't mounted right now (a normal, self-resolving state — see
# waitForMount.nix). Failing the whole system build over the latter would
# block unrelated changes; a warning surfaces the former without that cost.
lib: service: vol:
if vol == "" || builtins.pathExists vol then
  vol
else
  lib.warn
    "custom.storage.volumes.${service} = \"${vol}\" does not currently exist. If the volume is just unmounted right now, this is expected. If this is a typo, fix it in .local/storage/flake.nix."
    vol
