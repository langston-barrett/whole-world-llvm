# * libraries
#
# Here are some pre-configured bitcode builds.
#
{ pkgs        ? import ./pinned-pkgs.nix { }
, stdenv      ? pkgs.llvmPackages_6.libcxxStdenv
, llvm        ? pkgs.llvm_6
, extraAttrs ? x: x
}:

let
  makeBitcode = import ./make-bitcode.nix { inherit pkgs stdenv llvm extraAttrs; };
in with pkgs; {

  # This derivation manually overrides cmakeFlags
  libcxxabi = import ./make-bitcode.nix {
      inherit pkgs;
      extraAttrs = oldAttrs:
        let flags = pkgs.lib.concatStringsSep " " oldAttrs.cmakeFlags;
        in oldAttrs // {
        postUnpack = ''
          unpackFile ${libcxx.src}
          unpackFile ${llvm.src}
          export cmakeFlags="-DLLVM_PATH=$PWD/$(ls -d llvm-*) -DLIBCXXABI_LIBCXX_PATH=$PWD/$(ls -d libcxx-*) ${flags}"
        '';
      };
    } libcxxabi;

  libcxx = makeBitcode libcxx;
  # glog   = makeBitcode glog;
}
