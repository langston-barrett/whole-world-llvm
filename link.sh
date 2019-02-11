#!/run/current-system/sw/bin/env nix-shell
#!nix-shell --pure -i bash -p llvm_6

# Link together some LLVM bitcode files

set -e

if [[ "" == "$@" ]]; then
  echo "Usage: $0 file.bc dir1 dir2 ..."
fi

inst() {
  cp "$1" "$2"
  chmod 0640 "$2"
  # install --mode="rw-r-----" "$1" "$tmp"
}

out="$PWD/linked.$(basename $1)"
tmp="$PWD/temp.$(basename $1)"
inst "$1" "$out"
inst "$1" "$tmp"

args=( "$@" )
for dir in "${args[@]:1}"; do # oh, bash...
  llvm-link -only-needed "$out" $dir/*.bc > "$tmp"
  mv "$tmp" "$out"
done

echo "Unlinked:"
llvm-nm -u "$1" | wc -l
ls -alh "$1"
echo "Linked:"
llvm-nm -u "$out" | wc -l
ls -alh "$out"

llvm-dis "$out"
