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
    Unit.Description = "OBS Studio autostart";
    Service.ExecStart = "${pkgs.wrapOBS { plugins = with pkgs.obs-studio-plugins; [ obs-ndi ]; }}/bin/obs --minimize-to-tray --start-virtual-cam";
    Service.Environment = [ "NDI_IP=127.0.0.1" ];
    Install.WantedBy = [ "default.target" ];
  };
}
