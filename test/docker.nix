{ pkgs, pkgsLinux }:
pkgs.dockerTools.buildLayeredImage {
  name = "nix-flakes";
  tag = "latest";
  contents = [
    pkgsLinux.dockerTools.usrBinEnv
    pkgsLinux.dockerTools.binSh
    pkgsLinux.toybox
    (pkgsLinux.lib.setPrio 0 pkgsLinux.coreutils)
    pkgsLinux.glibc
    pkgsLinux.stdenv.cc.cc.lib
  ];
  config = {
    # WorkingDir = "/data";
    Env =
      [
        "LD_LIBRARY_PATH=/lib:/lib64"
      ];
  };
}
