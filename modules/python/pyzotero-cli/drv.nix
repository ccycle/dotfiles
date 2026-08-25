{
  lib,
  buildPythonPackage,
  src,

  # build-system
  setuptools,

  # dependencies
  click,
  pyyaml,
  pyzotero,
  tabulate,
  python-dotenv,

  # tests
  pytestCheckHook,
}:

buildPythonPackage rec {
  pname = "pyzotero-cli";
  version = "1.0.0";
  pyproject = true;

  inherit src;

  # pytest is incorrectly listed as a runtime dependency upstream.
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail '"pytest>=9.0",' ""
  '';

  build-system = [ setuptools ];

  dependencies = [
    click
    pyyaml
    pyzotero
    tabulate
    python-dotenv
  ];

  nativeCheckInputs = [ pytestCheckHook ];

  pythonImportsCheck = [ "pyzotero_cli" ];

  # Tests attempt to write to the home directory, which is read-only in the Nix sandbox.
  doCheck = false;

  meta = {
    description = "Use Zotero from the command line — CLI wrapper for pyzotero";
    homepage = "https://github.com/chriscarrollsmith/pyzotero-cli";
    license = lib.licenses.mit;
    mainProgram = "zot";
  };
}
