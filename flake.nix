{
  description = "Cosmic expansion WASM dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    ghc-wasm.url = "github:haskell-wasm/ghc-wasm-meta";
  };

  outputs = { self, nixpkgs, ghc-wasm, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.${system}.default = pkgs.mkShell {
        inputsFrom = [ ghc-wasm.devShells.${system}.default ];
      };
    };
}
