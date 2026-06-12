{
  description = "dev env";
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # tracks nixpkgs unstable branch
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    devenv.url = "github:ramblurr/nix-devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    clj-helpers.url = "github:outskirtslabs/clojure-nix-locker-helpers";
    clj-helpers.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    inputs@{
      self,
      devenv,
      devshell,
      clj-helpers,
      ...
    }:
    let
      package =
        pkgs:
        clj-helpers.lib.mkCljLib {
          inherit pkgs;
          name = "sops";
          version = "0.1.0";
          src = ./.;
          prefetchAliases = [ "kaocha" ];
          checkCommand = "clojure -Srepro -M:kaocha";
          gitRev = clj-helpers.lib.gitRev self;
          nativeBuildInputs = [
            pkgs.sops
          ];
        };
    in
    devenv.lib.mkFlake ./. {
      inherit inputs;
      withOverlays = [
        devshell.overlays.default
        devenv.overlays.default
      ];
      packages = {
        default = package;
        locker = pkgs: (package pkgs).locker;
      };
      devShell =
        pkgs:
        let
          jdk = pkgs.jdk25;
          clojure = pkgs.clojure.override { inherit jdk; };
        in
        pkgs.devshell.mkShell {
          imports = [
            devenv.capsules.base
            devenv.capsules.clojure
          ];
          packages = [
            self.packages.${pkgs.system}.locker
            pkgs.dumbpipe
            pkgs.git
            pkgs.sops
            (pkgs.writeScriptBin "run-clojure-mcp" ''
              #!/usr/bin/env bash
                set -euo pipefail
                PORT_FILE=''${1:-.nrepl-port}
                PORT=''${1:-4888}
                if [ -f "$PORT_FILE" ]; then
                PORT=$(cat ''${PORT_FILE})
                fi
                ${clojure}/bin/clojure -X:mcp/clojure :port $PORT
            '')
          ];
        };
      treefmtConfig = {
        programs = {
          nixfmt.enable = true;
          cljfmt.enable = true;
        };
      };
    };
}
