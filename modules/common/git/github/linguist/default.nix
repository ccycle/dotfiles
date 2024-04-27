{ callPackage }:
callPackage ../../../../../utils/mkDerivationFromGitHubRelease.nix { }
{
  url = "https://github.com/github-linguist/linguist/releases/download/v7.29.0/linguist-grammars.tar.gz";
  sha256 = "02sf3p0gnp3a0dhi63pglp5jbd33gybzsv0r9vjvsy92xdmq4kdr";
}
