{ bundlerApp }:
bundlerApp {
  pname = "github-linguist";
  exes = ["github-linguist"];
  gemdir = ./.;
}