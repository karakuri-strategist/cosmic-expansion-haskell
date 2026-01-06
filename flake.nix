{
  description = "Cosmic expansion WASM dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    ghc-wasm.url = "git+https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta.git";
  };

  outputs = { self, nixpkgs, ghc-wasm, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      nativeLibs = [
        pkgs.gmp
        pkgs.mesa
        pkgs.mesa_glu
        pkgs.freeglut
        pkgs.xorg.libX11
      ];
    in {
      devShells = {
        ${system} = {
          native = pkgs.mkShell {
            packages =
              [
                pkgs.stack
                pkgs.cabal-install
                pkgs.hpack
                pkgs.ghcid
                pkgs.haskell-language-server
                pkgs.pkg-config
              ]
              ++ nativeLibs;
            shellHook = ''
              export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath nativeLibs}:$LD_LIBRARY_PATH"
            '';
          };

          wasm = pkgs.mkShell {
            packages = [
              ghc-wasm.packages.${system}.default
              ghc-wasm.packages.${system}.cabal
              pkgs.cabal-install
              pkgs.hpack
              pkgs.nodejs
              pkgs.pnpm
            ];
          };

          default = self.devShells.${system}.native;
        };
      };
    };
}
