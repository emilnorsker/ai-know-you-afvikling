{
  description = "YOLOv11 Face Detection development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;
          };
        };
        
        ultralytics-thop = ps: ps.buildPythonPackage rec {
          pname = "ultralytics-thop";
          version = "2.0.11";
          format = "pyproject";
          
          src = pkgs.fetchFromGitHub {
            owner = "ultralytics";
            repo = "thop";
            rev = "v${version}";
            hash = "sha256-f3Lg/sgYlMvu2/7EDXda43ZLVOnXmWkOc29rmQYR34g=";
          };
          
          nativeBuildInputs = with ps; [ setuptools ];
          
          propagatedBuildInputs = with ps; [
            pytorch
          ];
          
          doCheck = false;
          
          meta = with pkgs.lib; {
            description = "FLOPs counter for PyTorch models";
            homepage = "https://github.com/ultralytics/thop";
            license = licenses.mit;
          };
        };
        
        ultralytics = ps: ps.buildPythonPackage rec {
          pname = "ultralytics";
          version = "8.3.61";
          format = "pyproject";
          
          src = ps.fetchPypi {
            inherit pname version;
            hash = "sha256-bL7RXyRH/5PTfK+mHxgWylvzM77ItzojeeqOh83FzK8=";
          };
          
          nativeBuildInputs = with ps; [ setuptools ];
          
          propagatedBuildInputs = with ps; [
            numpy
            opencv4
            pillow
            pytorch
            torchvision
            pyyaml
            tqdm
            requests
            huggingface-hub
            matplotlib
            pandas
            seaborn
            py-cpuinfo
            (ultralytics-thop ps)
          ];
          
          pythonImportsCheck = [ "ultralytics" ];
          doCheck = false;
          dontCheckRuntimeDeps = true;
          
          meta = with pkgs.lib; {
            description = "Ultralytics YOLO";
            homepage = "https://github.com/ultralytics/ultralytics";
            license = licenses.agpl3Only;
          };
        };
        
        finalPython = pkgs.python3.withPackages (ps: [
          (ultralytics ps)
          (ultralytics-thop ps)
        ] ++ (with ps; [
          numpy
          opencv4
          pillow
          pytorch
          torchvision
          pyyaml
          tqdm
          requests
          huggingface-hub
          matplotlib
          pandas
          seaborn
          py-cpuinfo
        ]));
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            finalPython
            pkgs.ffmpeg
          ];
          
          shellHook = ''
            echo "YOLOv11 Face Detection environment readyudp://127.0.0.1:1377"
            echo "Run: python detect_faces_yolo11.py --source <video_file> --port 1377"
            echo "Connect in OBS: Media Source → tcp://localhost:1377"
          '';
        };
      }
    );
}

