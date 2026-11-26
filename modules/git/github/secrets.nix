{ ... }:
{
  sops.secrets.github-pat-ccycle = {
    sopsFile = ./secrets.yaml;
    format = "yaml";
  };
}
