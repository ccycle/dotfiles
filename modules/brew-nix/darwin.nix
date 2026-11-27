{ pkgs, inputs, ... }:
{
  brew-nix.enable = true;
  imports = [ inputs.brew-nix.darwinModules.default ];

  environment.systemPackages = [
    (pkgs.brewCasks.desktoppr.overrideAttrs (o: {
      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        cp ./usr/local/bin/desktoppr $out/bin/
        runHook postInstall
      '';
    }))
    pkgs.brewCasks.appcleaner
    (pkgs.runCommand "google-japanese-ime-relinked" { } ''
      cp -a ${
        pkgs.brewCasks.google-japanese-ime.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.p7zip ];
          src = old.src.overrideAttrs {
            outputHash = "sha256-48QH2tIE4kMY50s3HS1Loytg3S99cQo14sbgFEc4AKQ=";
          };
          unpackPhase = ''
            7z x $src -o_dmg
            for pkg in _dmg/**/*.pkg; do
              xar -xf "$pkg"
            done
            for payload in $(cat Distribution | grep -oE "#.+\.pkg" | sed -e "s/^#//" -e "s/$/\/Payload/"); do
              zcat "$payload" | cpio -i
            done
          '';
        })
      } "$out"
      chmod -R u+w "$out"
      find "$out/Applications" -type l | while IFS= read -r link; do
        target="$(readlink "$link")"
        case "$target" in
        /Library/*) ln -sfn "$out$target" "$link" ;;
        esac
      done
      find "$out/Applications" -type l | while IFS= read -r link; do
        case "$(readlink "$link")" in
        /nix/store/* | [!/]*) ;;
        *)
          echo "$link points outside the store; it dangles on a fresh machine and aborts the /Applications/Nix Apps rsync. Re-point it here." >&2
          exit 1
          ;;
        esac
      done
    '')
    pkgs.brewCasks.betterdisplay
    pkgs.brewCasks.zotero
  ];
}
