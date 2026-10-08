#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo 'Usage: blueretro-build [all | hw1|hw2 [all|system] | dbg system]' >&2
    exit 2
}

targets=()
archives=()
if [[ $# -eq 0 || ($# -eq 1 && $1 == all) ]]; then
    archives=(hw1 hw2)
    for hardware in hw1 hw2; do
        for config in /project/configs/$hardware/*; do
            [[ -f $config ]] && targets+=("$hardware:${config##*/}")
        done
    done
elif [[ $# -eq 2 && $1 =~ ^(hw1|hw2)$ && $2 == all ]]; then
    archives=("$1")
    for config in /project/configs/$1/*; do
        [[ -f $config ]] && targets+=("$1:${config##*/}")
    done
elif [[ $# -eq 2 && $1 =~ ^(hw1|hw2|dbg)$ && $2 =~ ^[a-z0-9_]+$ ]]; then
    [[ -f /project/configs/$1/$2 ]] || {
        echo "Missing configuration: configs/$1/$2. Mount the repository at /project." >&2
        exit 2
    }
    targets+=("$1:$2")
else
    usage
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

# ESP-IDF's environment script is not guaranteed to support nounset.
set +u
source "$IDF_PATH/export.sh"
set -u
cd "$build_source"
printf 'Building %d target(s).\n' "${#targets[@]}"
for target in "${targets[@]}"; do
    hardware=${target%%:*}
    system=${target#*:}
    build_dir="$build_source/build"
    sdkconfig="$build_source/sdkconfig.$hardware.$system"
    printf '\n=== Building %s %s ===\n' "$hardware" "$system"
    printf '%s %s %s\n' "$version" "$hardware" "$system" | cut -c -31 > "$build_source/version.txt"
    cp "/project/configs/$hardware/$system" "$sdkconfig"
    export BR_HW="_$hardware" BR_SYS="_$system"
    if [[ -d $build_dir ]]; then
        [[ $build_dir == /tmp/blueretro-build.*/build ]] || {
            echo "Refusing to clean unexpected build path: $build_dir" >&2
            exit 2
        }
        find "$build_dir" -mindepth 1 -delete
    fi
    idf.py -B "$build_dir" -D "SDKCONFIG=$sdkconfig" reconfigure build

    output="/project/build/docker/$hardware-$system"
    mkdir -p "$output/bootloader" "$output/partition_table"
    cp "$build_dir/BlueRetro_${hardware}_${system}.bin" "$output/"
    cp "$build_dir/bootloader/bootloader.bin" "$output/bootloader/"
    cp "$build_dir/partition_table/partition-table.bin" "$output/partition_table/"
    cp "$build_dir/ota_data_initial.bin" "$output/"
    cp version.txt "$output/"
    printf 'OTA firmware: %s/BlueRetro_%s_%s.bin\n' "$output" "$hardware" "$system"
done

for hardware in "${archives[@]}"; do
    archive="/project/build/docker/BlueRetro_${hardware}.zip"
    archive_entries=()
    for target in "${targets[@]}"; do
        [[ ${target%%:*} == "$hardware" ]] && archive_entries+=("$hardware-${target#*:}")
    done
    rm -f "$archive"
    (
        cd /project/build/docker
        zip -qr "$archive" "${archive_entries[@]}"
    )
    printf '\n%s archive: %s\n' "${hardware^^}" "$archive"
done
