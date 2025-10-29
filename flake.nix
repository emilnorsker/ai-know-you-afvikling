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
      obs-ndi-pkg = pkgs.writeShellScriptBin "obs-ndi" ''
        export NDI_IP=127.0.0.1
        exec ${pkgs.wrapOBS { plugins = with pkgs.obs-studio-plugins; [ obs-ndi ]; }}/bin/obs --start-virtual-cam "$@"
      '';
      
      # Shared kiosk configuration
      kioskConfig = {
        boot.loader.systemd-boot.enable = true;
        
        # Disable firewall (required by ndi - not really but there are so many ports to map so its a hack)
        networking.firewall.enable = false;
        
        # User configuration
        users.mutableUsers = true;
        users.users.obs = {
          isNormalUser = true;
          extraGroups = [ "wheel" "networkmanager" "video" "audio" "render" ];
        };
        
        # Avahi service for mDNS/DNS-SD
        services.avahi = {
          enable = true;
          nssmdns = true;
          openFirewall = true;
          publish = {
            enable = true;
            userServices = true;
            addresses = true;
            workstation = true;
          };
        };
        
        # Console autologin for the kiosk user
        services.getty.autologinUser = "obs";
        
        # Enable cage service for kiosk mode
        services.cage = {
          enable = true;
          user = "obs";
          program = "${obs-ndi-pkg}/bin/obs-ndi --disable-shutdown-check --always-on-top";
          environment = {
            WLR_LIBINPUT_NO_DEVICES = "1";
          };
        };
        
        environment.systemPackages = [ obs-ndi-pkg ];
        system.stateVersion = "25.05";
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

      packages.${system}.default = obs-ndi-pkg;

      nixosConfigurations = {
        # VM configuration for testing
        kiosk-vm = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            kioskConfig
            {
              networking.hostName = "kiosk-vm";
              
              # VM configuration
              virtualisation.vmVariant = {
                virtualisation = {
                  memorySize = 2048;
                  cores = 2;
                  graphics = true;
                };
              };
            }
          ];
        };

        # Real hardware configuration
        kiosk = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hardware-configuration.nix
            kioskConfig
            {
              networking.hostName = "kiosk";
            }
          ];
        };
      };

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
    #     ExecStart = "nix run git+https://github.com/emilnorsker/ai-know-you-afvikling.git";
    #     User = "obs";
    #   };
    # };

    # gnome autologin
    # services.xserver = {
    #   displayManager.gdm.enable = true;
    #   desktopManager.gnome.enable = true;
    # }

    # and then follow this for just login
    # https://help.gnome.org/admin/system-admin-guide/stable/login-automatic.html.en

    # or this for kiosk mode
    # https://discourse.nixos.org/t/how-to-configure-nixos-for-kiosk-or-fullscreen-applications/21855