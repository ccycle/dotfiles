{ ... }:
{
  sops.secrets.gitlab-pat-ccycle = {
    sopsFile = ./secrets.yaml;
    format = "yaml";
  };
}
