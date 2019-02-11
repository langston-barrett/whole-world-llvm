{ pkgs ? import ../../pinned-pkgs.nix { } }:

let
  # Import files from this project
  libs        = import ../../libs.nix { inherit pkgs; };
  makeBitcode = import ../../make-bitcode.nix { inherit pkgs; };

  this = with pkgs; callPackage ./default.nix { };

in with pkgs; linkFarm "bitcode" [
  { name = "this";      path = (makeBitcode this).bitcode; }
  { name = "glog";      path = (makeBitcode glog).bitcode; }
  { name = "libcxx";    path = libs.libcxx.bitcode;        }
  { name = "libcxxabi"; path = libs.libcxxabi.bitcode;     }
]
