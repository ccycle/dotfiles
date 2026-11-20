{ lib, ... }:

{
  options.custom.kiac = {
    enable = lib.mkEnableOption "kiac (Kubernetes on apple/container) and its reboot-resume agent";

    dnsServers = lib.mkOption {
      type = lib.types.nonEmptyListOf lib.types.str;
      description = ''
        Nameservers for the cluster's node VMs (kiac allows up to 3).
        Required: apple/container's vmnet gateway (192.168.64.1) answers no
        DNS on these hosts, so without this the nodes cannot pull images
        and stay NotReady.
      '';
    };
  };
}
