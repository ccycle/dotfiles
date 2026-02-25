{ pkgs, ... }: {
  launchd.user.agents.colima = {
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/colima.log";
      StandardErrorPath = "/tmp/colima.log";
    };
    script = ''
      exec ${pkgs.colima}/bin/colima start --foreground
    '';
  };
}
