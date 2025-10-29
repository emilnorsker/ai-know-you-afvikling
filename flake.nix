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
      # OBS scene collection and profile contents from repo
      obsSceneFile = pkgs.writeText "ai-know-you-obs.json" (builtins.readFile ./ai-know-you-obs.json);
      obsProfileIni = pkgs.writeText "basic.ini" (builtins.readFile ./basic.ini);
      # Precompute wrapped OBS with plugins (use signature supported by this nixpkgs)
      obsWithPlugins = pkgs.wrapOBS {
        plugins = with pkgs.obs-studio-plugins; [ obs-ndi ];
      };
      # Minimal Firefox wrapper for Cage
      firefoxKiosk = pkgs.writeShellScriptBin "firefox-kiosk" ''
        exec ${pkgs.firefox}/bin/firefox --kiosk about:blank "$@"
      '';
      obs-ndi-pkg = pkgs.writeShellScriptBin "obs-ndi" ''
        export NDI_IP=127.0.0.1
        # Use an ephemeral config/data/cache so OBS changes never persist
        _OBS_TMP="$(${pkgs.coreutils}/bin/mktemp -d -t obs-conf-XXXXXX)"
        export XDG_CONFIG_HOME="$_OBS_TMP"
        export XDG_DATA_HOME="$_OBS_TMP"
        export XDG_CACHE_HOME="$_OBS_TMP"
        export XDG_STATE_HOME="$_OBS_TMP"
        trap "${pkgs.coreutils}/bin/rm -rf \"$_OBS_TMP\"" EXIT INT TERM
        ${pkgs.coreutils}/bin/mkdir -p "$_OBS_TMP/obs-studio/basic/scenes"
        ${pkgs.coreutils}/bin/mkdir -p "$_OBS_TMP/obs-studio/basic/profiles/Untitled"
        ${pkgs.coreutils}/bin/cp ${obsSceneFile} "$_OBS_TMP/obs-studio/basic/scenes/ai-know-you.json"
        ${pkgs.coreutils}/bin/cp ${obsProfileIni} "$_OBS_TMP/obs-studio/basic/profiles/Untitled/basic.ini"
        exec ${obsWithPlugins}/bin/obs \
          --startvirtualcam \
          --profile "Untitled" \
          --collection "ai-know-you" \
          --scene "Display" \
          --disable-shutdown-check \
          --always-on-top \
          "$@"
      '';
      
      # Shared kiosk configuration
      kioskConfig = {
        boot.loader.systemd-boot.enable = true;
        
        # Disable firewall (required by ndi - not really but there are so many ports to map so its a hack)
        networking.firewall.enable = false;
        
        # Allow unfree packages at the system level
        nixpkgs.config.allowUnfree = true;
        
        # User configuration
        users.mutableUsers = true;
        users.users.obs = {
          isNormalUser = true;
          createHome = true;
          extraGroups = [ "wheel" "networkmanager" "video" "audio" "render" "input" ];
        };
        
        # Avahi service for mDNS/DNS-SD
        services.avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
          publish = {
            enable = true;
            userServices = true;
            addresses = true;
            workstation = true;
          };
        };
        
        # Enable X11 with GDM and GNOME desktop (disabled for Cage test)
        services.xserver = {
          enable = false;
          displayManager.gdm.enable = false;
          desktopManager.gnome.enable = false;
        };
       
        # Prevent any sleep/hibernate/auto-shutdown behavior on a kiosk
        systemd.sleep.extraConfig = ''
          AllowSuspend=no
          AllowHibernation=no
          AllowSuspendThenHibernate=no
          AllowHybridSleep=no
        '';
        # Mask sleep targets to be extra safe
        systemd.targets.sleep.enable = false;
        systemd.targets.suspend.enable = false;
        systemd.targets.hibernate.enable = false;
        systemd.targets.hybrid-sleep.enable = false;
        # Explicit logind keys (canonical options)
        services.logind = {
          lidSwitch = "ignore";
          lidSwitchDocked = "ignore";
          lidSwitchExternalPower = "ignore";
          powerKey = "ignore";
          suspendKey = "ignore";
          hibernateKey = "ignore";
        };
        

        # Disable GDM autologin while testing Cage
        services.displayManager.autoLogin.enable = false;
        
        # Disable TTY getty/autovt to avoid conflict with GDM autologin on tty1
        systemd.services."getty@tty1".enable = false;
        systemd.services."autovt@tty1".enable = false;
        
        # Enable cage service for kiosk mode
        services.cage = {
          enable = true;
          user = "obs";
          program = "${firefoxKiosk}/bin/firefox-kiosk";
          environment = {
            HOME = "/home/obs";
            XDG_CONFIG_HOME = "/home/obs/.config";
            XDG_DATA_HOME = "/home/obs/.local/share";
            XDG_CACHE_HOME = "/home/obs/.cache";
            XDG_STATE_HOME = "/home/obs/.local/state";
            # Provide Wayland runtime dir (created by RuntimeDirectory below)
            XDG_RUNTIME_DIR = "/run/obs-runtime";
            MOZ_ENABLE_WAYLAND = "1";
          };
        };

        
        environment.systemPackages = [ obs-ndi-pkg pkgs.git pkgs.neovim ];
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
    # Examples if configuring outside this flake/module:
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
    #   extraGroups = [ "wheel" "networkmanager" "video" "audio" "render" ];
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

    # GNOME with GDM + autologin (alternative to cage):
    # services.xserver.enable = true;
    # services.xserver.displayManager.gdm.enable = true;
    # services.xserver.desktopManager.gnome.enable = true;
    # services.displayManager.autoLogin.enable = true;
    # services.displayManager.autoLogin.user = "obs";

    # and then follow this for just login
    # https://help.gnome.org/admin/system-admin-guide/stable/login-automatic.html.en

    # or this for kiosk mode
    # https://discourse.nixos.org/t/how-to-configure-nixos-for-kiosk-or-fullscreen-applications/21855