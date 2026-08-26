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
      # silently building for a nonexistent user.
      username = "";
      homeDirectory = "";
    };
}
