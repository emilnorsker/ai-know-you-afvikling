{
  description = "Dev shell with NDI, OBS Studio, and steam-run";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          ffmpeg
          ndi
          (wrapOBS {
            plugins = with obs-studio-plugins; [
              obs-ndi
            ];
          })
          steam-run
          avahi
        ];
        
        shellHook = ''
          export NDI_IP=127.0.0.1
        '';
      };

    };
}
    # needs to be set in configuration.nix
    # avahi = {
    #   enable = true;
    #   nssmdns = true;
    #   openFirewall = true;
    #   publish = {
    #     enable = true;
    #     userServices = true;
    #     addresses = true;
    #     workstation = true;
    #   };
    # };