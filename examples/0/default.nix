{ stdenv
, lib
, glog
}:

stdenv.mkDerivation {
  name = "example0";
  src  = lib.sourceFilesBySuffices ./. [ ".cpp" "Makefile" ];
  buildInputs = [
    glog
  ];
}
