#!/usr/bin/env bash
set -euo pipefail

hardware=${1:-hw1}
system=${2:-n64}
if [[ $# -gt 2 || ! $hardware =~ ^(hw1|hw2|dbg)$ || ! $system =~ ^[a-z0-9_]+$ ]]; then
    echo 'Usage: blueretro-build [hw1|hw2|dbg] [system, default: n64]' >&2
    exit 2
fi
if [[ ! -f /project/configs/$hardware/$system ]]; then
    echo "Missing configuration: configs/$hardware/$system. Mount the repository at /project." >&2
    exit 2
fi
if [[ ! -f /project/components/queue_bss/liblfds/liblfds7.1.1/liblfds711/inc/liblfds711.h ]]; then
    echo 'Initialize dependencies first: git submodule update --init --recursive' >&2
    exit 2
fi

# Build a snapshot including uncommitted edits, without replacing host sdkconfig
# or version.txt. Each target gets a separate output directory.
build_source=$(mktemp -d /tmp/blueretro-build.XXXXXX)
tar -C /project --exclude='./.git' --exclude='./build' --exclude='./sdkconfig' \
    --exclude='./sdkconfig.old' --exclude='./version.txt' -cf - . | tar -C "$build_source" -xf -
version=${BR_BUILD_VERSION:-$(git -c safe.directory=/project -C /project describe --always --tags --dirty 2>/dev/null || printf 'local')}
printf '%s %s %s\n' "$version" "$hardware" "$system" | cut -c -31 > "$build_source/version.txt"
cp "/project/configs/$hardware/$system" "$build_source/sdkconfig"

# ESP-IDF's environment script is not guaranteed to support nounset.
set +u
source "$IDF_PATH/export.sh"
set -u
cd "$build_source"
export BR_HW="_$hardware" BR_SYS="_$system"
idf.py reconfigure build

output="/project/build/docker/$hardware-$system"
mkdir -p "$output/bootloader" "$output/partition_table"
cp "build/BlueRetro_${hardware}_${system}.bin" "$output/"
cp build/bootloader/bootloader.bin "$output/bootloader/"
cp build/partition_table/partition-table.bin "$output/partition_table/"
cp build/ota_data_initial.bin "$output/"
cp version.txt "$output/"
printf '\nOTA firmware: %s/BlueRetro_%s_%s.bin\n' "$output" "$hardware" "$system"
