{
  description = "dev env";
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # tracks nixpkgs unstable branch
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    devenv.url = "github:ramblurr/nix-devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    clj-nix.url = "github:jlesquembre/clj-nix";
    clj-nix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    inputs@{
      self,
      clj-nix,
      devenv,
      devshell,
      ...
    }:
    devenv.lib.mkFlake ./. {
      inherit inputs;
      withOverlays = [
        devshell.overlays.default
        devenv.overlays.default
        clj-nix.overlays.default
      ];
      packages = {
        default =
          pkgs:
          let
            root = toString ./.;
            gitRev =
              if self ? rev then
                self.rev
              else if self ? dirtyRev then
                self.dirtyRev
              else
                "dirty";
            projectSrc = pkgs.lib.cleanSourceWith {
              src = ./.;
              filter =
                path: _type:
                let
                  rel = pkgs.lib.removePrefix (root + "/") (toString path);
                  base = builtins.baseNameOf path;
                in
                !(base == ".git" || rel == "result" || pkgs.lib.hasPrefix "target/" rel);
            };
          in
          pkgs.mkCljLib {
            inherit projectSrc;
            name = "com.outskirtslabs/sops";
            version = "0.1.0";
            nativeBuildInputs = [
              pkgs.coreutils
              pkgs.sops
            ];
            GIT_REV = gitRev;
            JAVA_HOME = pkgs.jdk25.home;
            buildCommand = ''
              export JAVA_HOME="${pkgs.jdk25.home}"
              export JAVA_CMD="${pkgs.jdk25}/bin/java"
              clojure -M:kaocha
              clojure -T:build jar
            '';
          };
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
