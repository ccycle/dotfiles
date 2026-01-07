{ stdenv, fetchurl, lib }:

stdenv.mkDerivation rec {
  pname = "cursor-agent";
  version = "2026.01.02-80e4d9b";

  src = fetchurl {
    url = "https://downloads.cursor.com/lab/${version}/darwin/arm64/agent-cli-package.tar.gz";
    sha256 = "0g84ad4mycwcg7h3mpqjkrkk836hbx7icqx6k4f14lapcdyxlb87";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/cursor-agent
    cp -R . $out/share/cursor-agent/

    mkdir -p $out/bin
    ln -s $out/share/cursor-agent/cursor-agent $out/bin/cursor-agent
    ln -s $out/share/cursor-agent/cursor-agent $out/bin/agent

    runHook postInstall
  '';

  meta = {
    description = "Cursor Agent CLI";
    homepage = "https://cursor.com";
    platforms = [ "aarch64-darwin" ];
    mainProgram = "cursor-agent";
  };
}
