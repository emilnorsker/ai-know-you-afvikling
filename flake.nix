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

      packages.${system}.default = pkgs.writeShellScriptBin "obs-ndi" ''
        export NDI_IP=127.0.0.1
        exec ${pkgs.wrapOBS { plugins = with pkgs.obs-studio-plugins; [ obs-ndi ]; }}/bin/obs --start-virtual-cam "$@"
      '';

    };
}
    # needs to be set in configuration.nix:
    # 
    # services.avahi = {
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
    # 
    # # Optional: Create dedicated user for OBS service
    # users.users.obs = {
    #   isNormalUser = true;
    #   extraGroups = [ "audio" "video" "render" ];
    # };
    # 
    # # Example of how to define systemd services directly in configuration.nix:
    # systemd.services.myservice = {
    #   enable = true;
    #   description = "My Service";
    #   wantedBy = [ "graphical.target" ];
    #   path = [ pkgs.nix ];
    #   serviceConfig = {
    #     ExecStart = "nix run git+https://emilnorsker/ai-know-you-afvikling.git";
    #     User = "obs";
    #   };
    # };