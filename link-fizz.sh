#!/run/current-system/sw/bin/env nix-shell
#!nix-shell --pure -i bash -p llvm_6

# Link the HkdfTest.bc file with only what is needed for the SAW verification to
# run.

set -e

f="$PWD/result/fizz/HkdfTest.bc"

inst() {
  cp "$1" "$2"
  chmod 0640 "$2"
  # install --mode="rw-r-----" "$1" "$tmp"
}

in="$PWD/result/fizz/HkdfTest.bc"
out="$PWD/linked.$(basename $f)"
tmp="$PWD/temp.$(basename $f)"
inst "$in" "$out"
inst "$in" "$tmp"

link() {
  llvm-link -only-needed "$out" "$1" > "$tmp"
  mv "$tmp" "$out"
}

link "$PWD/result/gtest-1.8.1/gtest-all.bc"
link "$PWD/result/libcxx/iostream.bc"

echo "Unlinked:"
llvm-nm -u "$in" | wc -l
ls -alh "$in"
echo "Linked:"
llvm-nm -u "$out" | wc -l
ls -alh "$out"

llvm-dis "$out"
