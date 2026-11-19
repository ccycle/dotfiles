{ config, ... }:
{
  # Local destination for hosts without services.staticReports (the private
  # profile shared with the work PC). publish.sh prefers STATIC_REPORTS_DIR
  # when that host module exports it.
  home.sessionVariables.HTML_REPORTS_DIR = "${config.home.homeDirectory}/html-reports";
}
