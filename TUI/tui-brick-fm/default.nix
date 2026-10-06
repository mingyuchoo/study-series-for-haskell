# default.nix
let
  pkgs = import <nixpkgs> {};
  compilerVersion = "ghc9122";
  compiler = pkgs.haskell.packages."${compilerVersion}";
in
  compiler.developPackage {
  root = ./.;
  modifier = drv:
    pkgs.haskell.lib.addBuildTools drv (
      with pkgs.haskellPackages;
      [ stack
        cabal-install
        stylish-haskell
        haskell-language-server
        hindent
        hlint
        hoogle
        ghcid
      ]
    );
}
