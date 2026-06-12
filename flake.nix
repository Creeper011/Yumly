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
          version = "0.9.0";
          src = ./.;

          nativeBuildInputs = [ pkgs.nim ];
          buildInputs = [ pkgs.openssl ];

          buildPhase = ''
            export HOME=$TMPDIR
            # Add dependencies to Nim path
            nim c -d:release --opt:size \
              --path:${nimpy-src} \
              --path:${dotenv-src}/src \
              --path:${yaml-src} \
              -o:yumly-cli -d:yumlyJson -d:yumlyYaml utils/yumly_cli.nim
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp yumly-cli $out/bin/
          '';
        };

        devShells.default = import ./shell.nix { inherit pkgs; };
      }
    );
}
