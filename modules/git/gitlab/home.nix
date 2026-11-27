{ pkgs, ... }:
{
  home.packages = with pkgs; [
    glab
    (gitlab-runner.overrideAttrs { doCheck = !pkgs.stdenv.hostPlatform.isDarwin; })
  ];
}
