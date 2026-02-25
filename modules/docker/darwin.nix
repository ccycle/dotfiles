{ pkgs, ... }: {
  # Remove the Docker Desktop symlink at /var/run/docker.sock if it exists.
  # Docker Desktop creates this symlink, but we use Colima instead.
  system.activationScripts.cleanDockerDesktopSocket.text = ''
    if [ -L /var/run/docker.sock ]; then
      echo "Removing Docker Desktop socket symlink..."
      rm -f /var/run/docker.sock
    fi
  '';

  launchd.user.agents.colima = {
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/colima.log";
      StandardErrorPath = "/tmp/colima.log";
    };
    script = ''
      export PATH="${pkgs.docker}/bin:$PATH"
      exec ${pkgs.colima}/bin/colima start --foreground
    '';
  };
}
