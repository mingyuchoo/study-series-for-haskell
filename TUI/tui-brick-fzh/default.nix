let
  pkgs = import <nixpkgs> {};
in
pkgs.mkShell {
  packages = with pkgs; [
    haskell.compiler.ghc9141
    stack
    cabal-install
    haskellPackages.stylish-haskell
    haskell-language-server
    haskellPackages.hindent
    hlint
    haskellPackages.hoogle
    haskellPackages.ghcid
  ];
  buildInputs = with pkgs; [ gmp ncurses zlib ];
}
