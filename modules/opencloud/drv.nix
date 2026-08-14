{ stdenv, fetchurl, lib, unzip }:

# OpenCloud web apps, installed as Nix packages and served via WEB_ASSET_APPS_PATH.
# The apps directory is built so each app lives in its own subdirectory holding a
# manifest.json, mirroring the layout expected by the OpenCloud web service.
# To add another app, fetch its release zip and unpack it here.
#
# Fetched from ccycle/opencloud-web-extension (a fork of opencloud-eu/web-extensions)
# rather than upstream: this build additionally supports server-side extraction
# (feat/server-side-unzip), not present in the upstream unzip app. The release
# zip is packaged with the same top-level "unzip/" layout upstream's own release
# uses, so this derivation is otherwise unchanged from the upstream version.
stdenv.mkDerivation rec {
  pname = "opencloud-web-apps";
  version = "2.1.0";

  src = fetchurl {
    url = "https://github.com/ccycle/opencloud-web-extension/releases/download/unzip-server-v${version}/unzip-server-${version}.zip";
    sha256 = "01y9jkwynh5v43l6ml4lj89aqf7kxq4yq334zs2nxr9idign6x8j";
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
    description = "OpenCloud web apps (unzip extension, server-side extraction fork)";
    homepage = "https://github.com/ccycle/opencloud-web-extension";
    license = lib.licenses.agpl3Plus;
    platforms = [ "aarch64-darwin" ];
  };
}