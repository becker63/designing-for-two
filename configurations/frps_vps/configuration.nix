{
  config,
  lib,
  pkgs,
  ...
}:

let
  frpcKclSrc = ./FRPC_Config.k;

  frpcConfigDrv =
    pkgs.runCommand "frpc-config"
      {
        nativeBuildInputs = [ pkgs.kcl ];
      }
      ''
        mkdir -p $out

        # Render KCL to JSON
        kcl ${frpcKclSrc} --format json > $out/frpc.json
      '';
in
{
  networking.hostName = "frpc-node";
  time.timeZone = "UTC";

  environment.systemPackages = [
    pkgs.kcl
    pkgs.frp
  ];

  systemd.services.frpc = {
    description = "FRPC client";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      ExecStart = ''
        ${pkgs.frp}/bin/frpc \
          -c ${frpcConfigDrv}/frpc.json
      '';

      Restart = "always";
      RestartSec = 2;
    };
  };

  systemd.network.wait-online.enable = true;
}
