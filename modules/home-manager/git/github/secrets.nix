{ ... }:
{
  sops.secrets.github-pat-ccycle = {
    sopsFile = ./secrets.yaml;
    format = "yaml";
  };
  sops.secrets.github-pat-primal-search = {
    sopsFile = ./secrets.yaml;
    format = "yaml";
  };
}
