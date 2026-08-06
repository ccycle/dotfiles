{ stdenv, fetchurl, lib, unzip }:

# OpenCloud web apps, installed as Nix packages and served via WEB_ASSET_APPS_PATH.
# The apps directory is built so each app lives in its own subdirectory holding a
# manifest.json, mirroring the layout expected by the OpenCloud web service.
# To add another app, fetch its release zip and unpack it here.
stdenv.mkDerivation rec {
  pname = "opencloud-web-apps";
  version = "2.1.0";

  src = fetchurl {
    url = "https://github.com/opencloud-eu/web-extensions/releases/download/unzip-v${version}/unzip-${version}.zip";
    sha256 = "1dnvssmwz1xairvzh2k0q61458flhx911w0cl2ia82c7c6z7dj0b";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ unzip ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    unzip "$src" -d $out
    rm -rf $out/__MACOSX 2>/dev/null || true

    runHook postInstall
  '';

  meta = {
    description = "OpenCloud web apps (unzip extension)";
    homepage = "https://github.com/opencloud-eu/web-extensions";
    license = lib.licenses.agpl3Plus;
    platforms = [ "aarch64-darwin" ];
  };
}