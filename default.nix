{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    ffmpeg
    ndi
    (wrapOBS {
      plugins = with obs-studio-plugins; [
        obs-ndi
      ];
    })
  ];

  systemd.user.services.obs-autostart = {
    enable = true;
    description = "OBS Studio autostart";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.wrapOBS { plugins = with pkgs.obs-studio-plugins; [ obs-ndi ]; }}/bin/obs --minimize-to-tray --start-virtual-cam";
      Environment = [ "NDI_IP=127.0.0.1" ];
    };
  };
}
