let
  pkgs = import <nixpkgs> {};
in
  pkgs.mkShell {
    packages = with pkgs; [
      stack
      cabal-install
      stylish-haskell
      haskell-language-server
      hlint
      hoogle
      ghcid
      gnumake
    ];
  }
