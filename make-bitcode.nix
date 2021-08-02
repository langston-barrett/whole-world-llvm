# * make bitcode
#
# Get all the LLVM bitcode out of a C(++) project.
#
# This function takes in a derivation. Using overrides, it makes clang(++) build
# the project as normal, but creating intermediate bitcode files. These are then
# added to a second output ("bitcode").
#
# TODO: Some derivations (e.g. libcxxabi) overwrite the cmakeFlags in a shell
# session (preBuild or similar). How can we fix that?
{ pkgs ? import ./pinned-pkgs.nix { }
, extraAttrs ? x: x
, stdenv ? pkgs.llvmPackages_10.libcxxStdenv
, llvm   ? pkgs.llvm_10

, extraCFlags ? ""
, extraCXXFlags ? ""
}:

with pkgs; drv:
builtins.trace ("[INFO] Making bitcode for " + drv.name or "<unknown name>")

# Overrides don't compose :'( If the package has already had an override
# applied, we'd better hope that it included putting it in a libc++ stdenv.
(if drv ? override
 then drv.override {
   inherit stdenv;
 }
 else builtins.trace ("[WARN] Not overriding stdenv for drv " + drv.name or "<unknown name>")
      drv).overrideAttrs (oldAttrs: extraAttrs rec {
  name = "llvm-bitcode-" + (oldAttrs.name or "dummy-name");
  buildInputs = (oldAttrs.buildInputs or []) ++ [llvm];
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [];
  propagatedBuildInputs = (oldAttrs.buildInputs or []) ++ [llvm];

  # https://nixos.org/nixpkgs/manual/#sec-multiple-outputs-
  outputs = [ "out" "bitcode" ];

  # This likely wont work if the old derivation overrides CMAKE_CXX_FLAGS
  CC          = "clang";
  CXX         = "clang++";
  CFLAGS      = "-O1 -g -save-temps=obj";
  cmakeFlags  = (oldAttrs.cmakeFlags or []) ++ [

    # Verbosity
    "-DCMAKE_INSTALL_MESSAGE=NEVER"
    "-DTARGET_MESSAGES=OFF"
    "-DRULE_MESSAGES=OFF"

    # General
    "-DCMAKE_EXPORT_COMPILE_COMMANDS=1"
    "-DCMAKE_BUILD_TYPE=RelWithDebInfo"

    # C++
    "-DCMAKE_CXX_COMPILER=clang++"
    "-DCMAKE_CXX_FLAGS=-save-temps=obj"

    # C
    "-DCMAKE_C_COMPILER=clang"
    "-DCMAKE_C_FLAGS=-save-temps=obj"
  ];

  preConfigure = ''
    ${oldAttrs.preConfigure or ""}

    # See https://github.com/NixOS/nixpkgs/issues/22668
    export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -O1 -g -fno-inline-functions -save-temps=obj"
  '';

  preBuild =  ''
    ${oldAttrs.preBuild or ""}

    export CPP="clang -E"
    makeFlagsArray=(CFLAGS="$CFLAGS -O1 -g -save-temps=obj -fno-inline-functions -Wno-unknown-warning-option ${extraCFlags}")
    makeFlagsArray=(CXXFLAGS="$CXXFLAGS -fno-threadsafe-statics -save-temps=obj ${extraCXXFlags}")
  '';

  # https://stackoverflow.com/questions/2937407/test-whether-a-glob-has-any-matches-in-bash
  installPhase = ''
    ${oldAttrs.installPhase or ""}

    # In case the old derivation doesn't install anything to $out
    mkdir -p "$out"
    if [[ -z "$(ls $out)" ]]; then
      touch "$out/dummy"
    fi

    # openssl workaround
    if [[ -n $debug ]]; then
      mkdir -p "$debug"
      touch "$out/dummy"
    fi

    # Install bitcode from a given folder
    install_bitcode() {
      echo "Installing bitcode from $1 to $bitcode"
      mkdir -p "$bitcode"
      for file in $(find "$1" -name "*.bc") \
                  $(find "$1" -name "*.ll") \
                  $(find "$1" -name "*.txt") ;
      do
        echo "Copying file $file"
        # Avoid name conflicts
        if [[ -f $bitcode/$(basename "$file") ]]; then
          cp "$file" "$bitcode"/2.$(basename "$file")

        else
          cp "$file" "$bitcode"
        fi
      done
    }
    install_bitcode "$(pwd)"

    # Gather further information
    # cp compile_commands.json $out
    # cp compile_commands.json $bitcode
    cd $bitcode
    exists() {
        [ -e "$1" ]
    }
    if exists *.bc; then
      for bc in *.bc; do
        echo "Disassembling $bc"
        (${llvm}/bin/llvm-dis $bc || true) &
        (${llvm}/bin/llvm-nm  $bc >> names.txt || true) &
        wait
      done
    else
      echo 'No bitcode produced for ${oldAttrs.name or "<unknown name>"}'
    fi
  '';
})
