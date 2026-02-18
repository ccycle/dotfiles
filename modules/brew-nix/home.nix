{ pkgs, ... }: {
  home.packages = [
    (pkgs.brewCasks.desktoppr.overrideAttrs (o: {
      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        cp ./usr/local/bin/desktoppr $out/bin/
        runHook postInstall
      '';
    }))
    # pkgs.brewCasks.wireshark-chmodbpf
    pkgs.brewCasks.appcleaner
  ];
}
