{
  description = "Yumly CLI ✨ - A cute, declarative config language with fail-fast behavior and optional type safety.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    
    # Dependencies
    nimpy-src = {
      url = "github:yglukhov/nimpy";
      flake = false;
    };
    dotenv-src = {
      url = "github:euantorano/dotenv.nim";
      flake = false;
    };
    yaml-src = {
      url = "github:flyx/NimYAML";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, nimpy-src, dotenv-src, yaml-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "yumly";
          version = "0.10.0";
          src = ./.;

          nativeBuildInputs = [ pkgs.nim ];
          buildInputs = [ pkgs.openssl ];

          buildPhase = ''
            export HOME=$TMPDIR
            export YUMLY_NIM_FLAGS="--path:${nimpy-src} --path:${dotenv-src}/src --path:${yaml-src}"
            nimble --nimbleDir:build/nimble buildCli
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp build/bin/yumly-cli $out/bin/
          '';
        };

        devShells.default = import ./shell.nix { inherit pkgs; };
      }
    );
}
