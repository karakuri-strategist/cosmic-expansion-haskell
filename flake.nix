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
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          ghc-wasm.packages.${system}.default
          ghc-wasm.packages.${system}.cabal
        ];
      };
    };
}
