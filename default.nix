# * Fizz and Folly Nix build
#
# This file controls the overall build. The goal is to build Fizz, Folly, and
# all of their dependencies with Clang, and output the bitcode to a single
# directory.
#
{ pkgs   ? import ./pinned-pkgs.nix { }
, stdenv ? pkgs.llvmPackages_6.libcxxStdenv
}:

let
    # pkgs   = import (pkgsOld.fetchFromGitHub {
    #   owner   = "NixOS";
    #   repo    = "nixpkgs";
    #   rev     = "17.03";
    #   sha256  = "1fw9ryrz1qzbaxnjqqf91yxk1pb9hgci0z0pzw53f675almmv9q2";
    # }) { };

    makeBitcode = import ./make-bitcode.nix {
      inherit pkgs;
      extraAttrs = oldAttrs: oldAttrs // {
        doCheck    = false;
        cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [ "-DBUILD_TESTING=0" ];
      };
    };

    makeLinkFarmInput = x: {
      inherit (x) name;
      path = makeBitcode x;
    };

    # The filter function just picks everything in the list
    lst  = ["gtest" "gmock" "folly"];
    anyt = builtins.any (z: z == true);
    filt = drv: anyt (map (s: pkgs.lib.strings.hasPrefix s (drv.name or "")) lst);
    wwllvm = import ./whole-world-llvm.nix {
      inherit pkgs stdenv;
      llvm = pkgs.llvm_6;
    };

    follyVersions = {
      "2018.10.29.00" = {
        sha256 = "0bbp4w8wbawh3ilgkl7rwvbqkdczpvfn92f9lcvxj8sili0nldab";
      };
      "2018.12.10.00" = {
        sha256 = "0pqv6xl4ll6y3mc849y1vcwqlcnm2a1yh23df24rzdsx57adxjb8";
      };
      "2019.01.07.00" = {
        sha256 = "19vqcln8r42741cpj9yd3pdmr0rd07kg1pzqcyjl94dhpg3gmqhs";
      };
    };
    follyVersion = "2018.12.10.00";
    follySrc     = pkgs.fetchFromGitHub {
      inherit (follyVersions.${follyVersion}) sha256;
      owner  = "facebook";
      repo   = "folly";
      rev    = "v${follyVersion}";
    };

    fizzVersions = {
      "20181030" = {
        rev    = "272813416984d3399cdc32021e8aeedd92cf402d";
        sha256 = "1g415wflhycfd2i92i5hpizdiy4wbgcc14l0armdyvbd09px1xwz";
      };
      "20190110" = {
        rev    = "eaf86f0f9d446cb09b85260ac7cef899675bcf84";
        sha256 = "0pg2gfjbfslhxvby8h9aggvbjpqi33swhl4vdss2vb8px5mm1q6g";
      };
    };
    fizzVersion = "20181030";
    fizzSrc = pkgs.fetchFromGitHub {
      inherit (fizzVersions.${fizzVersion}) rev sha256;
      owner  = "facebookincubator";
      repo   = "fizz";
    };

in with pkgs; rec {
  gflags    = (import ./google-libs.nix { inherit stdenv pkgs; }).gflags;
  glog      = (import ./google-libs.nix { inherit stdenv pkgs; }).glog;
  gmock     = (import ./google-libs.nix { inherit stdenv pkgs; }).gmock;
  gtest     = (import ./google-libs.nix { inherit stdenv pkgs; }).gtest;

  folly     = with pkgs; callPackage ./folly.nix {
    inherit stdenv;
    inherit gflags glog;
    version = follyVersion;
    src     = follySrc;
    # double-conversion = double_conversion;
    # gflags            = google-gflags;
  };

  fizz = callPackage ./fizz.nix {
    inherit stdenv folly;
    inherit gflags glog gmock gtest;
    version = fizzVersion;
    src     = fizzSrc;
  };

  follybc     = makeBitcode folly;
  fizzbc      = makeBitcode fizz;
  libcxxbc    = makeBitcode libcxx;

  # This derivation manually overrides cmakeFlags
  libcxxabibc = import ./make-bitcode.nix {
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

  fizzww = wwllvm {
    inherit filt;
    drv = fizz;
    additional = [
    {
      name = "libcxx";
      path = libcxxbc.bitcode;
    }
    {
      name = "libcxxabi";
      path = libcxxabibc.bitcode;
    }];
    # additional = map makeLinkFarmInput [
    #   libcxxbc.bitcode
    # ];
  };

  gtestbc = (import ./make-bitcode.nix { inherit pkgs; }) gtest;
}
