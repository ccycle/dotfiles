{ config, ... }:

{
  imports = [
    ./secrets.nix
  ];

  nix.settings = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://ccycle.cachix.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "ccycle.cachix.org-1:rEb6IyD7NBEujI5+0MrkgdDNWuz+UMe8sDyttbaEnRE="
    ];
  };
}
