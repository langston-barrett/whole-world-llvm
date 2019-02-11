# * Whole world LLVM

# A Nix function for creating one big bitcode file for a whole C++ program,
# including all of the libraries it uses.

# Status: Currently uses symlinkJoin to create a directory containing all the
# bitcode

# This is currently unrealistic: We don't want to recompile e.g. Clang and CMake.
# How can we do just the C++ libraries?
# Idea: Introduce a filter function, it could work on names at least.

{ pkgs   ? import ./pinned-pkgs.nix { }
, stdenv ? pkgs.llvmPackages_6.libcxxStdenv
, llvm   ? pkgs.llvm_6
}:

let

  stringOrNull = set: str:
    if (set ? str) && (builtins.isString set.${str})
    then set.${str}
    else "";

  transitiveInputs = drv:
    [drv] ++ pkgs.lib.concatMap transitiveInputs (drv.buildInputs or []);

  makeBitcode = import ./make-bitcode.nix { inherit pkgs; };

  makeLinkFarmInput = x: {
    inherit (x) name;
    path = (makeBitcode x).bitcode;
  };

  linkFarmInputs = drv: filt:
    map makeLinkFarmInput (builtins.filter filt (transitiveInputs drv));

  /*
   * Stolen from nixpkgs. Modification prevents double-linking.
   *
   * Quickly create a set of symlinks to derivations.
   * entries is a list of attribute sets like
   * { name = "name" ; path = "/nix/store/..."; }
   *
   * Example:
   *
   * # Symlinks hello path in store to current $out/hello
   * linkFarm "hello" entries = [ { name = "hello"; path = pkgs.hello; } ];
   *
   */
  linkFarm = name: entries: pkgs.runCommand name { preferLocalBuild = true; }
    ("mkdir -p $out; cd $out; \n" +
      (pkgs.lib.concatMapStrings (x: ''
        if ! [[ -d ${x.name} ]]; then
          mkdir -p "$(dirname '${x.name}')"
          ln -s '${x.path}' '${x.name}'
        fi
      '') entries));

  wholeWorldLLVM =
    { filt ? x: false
    , drv
    , deps ? []
    }:
    linkFarm "wllvm-${drv.name}" (linkFarmInputs drv filt ++ deps);

  # wholeWorldLLVM =
  #   { filt ? x: true
  #   , drv
  #   , deps ? []
  #   }:
  #   (linkFarmInputs drv filt);

in wholeWorldLLVM
