{ pkgs ? import <nixpkgs> { }
, path ? ./json/nixpkgs-21.05.json
}:

# We've pinned version a of nixpkgs for reproducible builds.

# We had to pin a recent one to get a version of gtest which respects cmakeFlags

# See this link for a tutorial:
# https://github.com/Gabriel439/haskell-nix/tree/master/project0
#
# nix-shell -p nix-prefetch-git --run "nix-prefetch-git https://github.com/NixOS/nixpkgs.git 21.05 > json/nixpkgs-21.05.json"

let
  nixpkgs = builtins.fromJSON (builtins.readFile path);

  src = pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo  = "nixpkgs";
    inherit (nixpkgs) rev sha256;
  };

in import src { }
