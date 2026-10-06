# Workspace development tools; Stack resolves all local packages from stack.yaml.
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = with pkgs; [
    ghc stack cabal-install
    haskell-language-server haskellPackages.hlint haskellPackages.ghcid
    haskellPackages.stylish-haskell python3
  ];
}
