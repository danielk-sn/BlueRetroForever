# Build firmware with Docker or Podman

The image uses the same patched ESP-IDF image as this repository's build workflow.
The first image build requires network access. Firmware builds include local,
uncommitted source changes and run in a temporary directory inside the container.

From the repository root:

```sh
git submodule update --init --recursive
docker build -t blueretro-builder .
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD:/project" blueretro-builder
```

With no target arguments, the container builds every release system for both
HW1 and HW2. Artifacts are written to `build/docker/<hardware>-<system>/`, then
packaged as:

```text
build/docker/BlueRetro_hw1.zip
build/docker/BlueRetro_hw2.zip
```

Set `BR_BUILD_VERSION` to distinguish an uncommitted test image from other
builds made at the same Git revision:

```sh
docker run --rm -e BR_BUILD_VERSION=m64-sc-test1 \
  -v "$PWD:/project" blueretro-builder
```

On Linux with Podman (including SELinux systems):

```sh
git submodule update --init --recursive
podman build -t blueretro-builder .
podman run --rm --userns=keep-id -e HOME=/tmp \
  -v "$PWD:/project:Z" blueretro-builder
```

For an HW1 N64 adapter, upload this application image through BlueRetro's OTA page:

```text
build/docker/hw1-n64/BlueRetro_hw1_n64.bin
```

Bootloader, partition-table, OTA-initialization, and version files are exported
alongside it. Use only the application image for a web OTA update. The container
does not flash hardware. Host `sdkconfig` and `version.txt` are preserved.

For a faster targeted build, pass a hardware and system, for example `hw1 n64`
or `hw2 gamecube`. `hw1 all` and `hw2 all` build every system for one hardware
revision. Debug/QEMU configurations require an explicit target such as `dbg qemu`.
Complete hardware archives are created by the default build and by `hw1 all` or
`hw2 all`; a targeted single-system build does not replace those archives.

The base toolchain can be overridden with `--build-arg IDF_IMAGE=...` when building
the image; an arbitrary stock ESP-IDF image may lack BlueRetro's required patches.
