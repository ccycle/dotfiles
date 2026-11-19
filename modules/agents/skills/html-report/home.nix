{ config, osConfig, ... }:
let
  sr = osConfig.services.staticReports;
in
{
  # A file instead of env vars: it takes effect right after darwin-rebuild
  # for every process, with no shell restart, and is inspectable with cat.
  # Hosts without static-reports (the private profile shared with the work
  # PC) save locally and get no url line.
  xdg.configFile."html-report/destination".text =
    if sr.enable then
      ''
        dir=${sr.dataDir}/agent-reports
        url=${sr.url}/agent-reports
      ''
    else
      ''
        dir=${config.home.homeDirectory}/html-reports
      '';
}
