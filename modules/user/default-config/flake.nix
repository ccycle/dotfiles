{
  outputs =
    { ... }:
    {
      # Unlike the other default-config flakes, these are consumed directly
      # as specialArgs (not imported as a darwinModule) - username is needed
      # before module evaluation starts, to name the users.users./home-manager.users.
      # attribute. Left empty on purpose: ensure-local.sh always writes a real
      # .local/user before this default is ever evaluated; darwin.nix asserts
      # on an empty username so a missing override fails loudly instead of
      # silently building for a nonexistent user. Deliberately does not fall
      # back to reading $USER here as a friendlier default - that's the exact
      # failure mode this input replaced (env-impure.nix's $USER/$SUDO_USER
      # sniffing silently produced nothing usable under a launchd-spawned
      # process with no $USER set, and nobody noticed until CI hit it).
      username = "";
      homeDirectory = "";
    };
}
