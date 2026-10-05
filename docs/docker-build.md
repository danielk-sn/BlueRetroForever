# Build firmware with Docker or Podman

The image uses the same patched ESP-IDF image as this repository's build workflow.
The first image build requires network access. Firmware builds include local,
uncommitted source changes and run in a temporary directory inside the container.

From the repository root:

```sh
git submodule update --init --recursive
docker build -t blueretro-builder .
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD:/project" blueretro-builder hw1 n64
```

Set `BR_BUILD_VERSION` to distinguish an uncommitted test image from other
builds made at the same Git revision:

```sh
docker run --rm -e BR_BUILD_VERSION=m64-sc-test1 \
  -v "$PWD:/project" blueretro-builder hw1 n64
```

On Linux with Podman (including SELinux systems):

```sh
git submodule update --init --recursive
podman build -t blueretro-builder .
podman run --rm --userns=keep-id -e HOME=/tmp \
  -v "$PWD:/project:Z" blueretro-builder hw1 n64
```

For an HW1 N64 adapter, upload this application image through BlueRetro's OTA page:

```text
build/docker/hw1-n64/BlueRetro_hw1_n64.bin
```

Bootloader, partition-table, OTA-initialization, and version files are exported
alongside it. Use only the application image for a web OTA update. The container
does not flash hardware. Host `sdkconfig` and `version.txt` are preserved.

`hw1 n64` is the default. Other arguments must correspond to a file under
`configs/<hardware>/<system>`, for example `hw2 gamecube`.

The base toolchain can be overridden with `--build-arg IDF_IMAGE=...` when building
the image; an arbitrary stock ESP-IDF image may lack BlueRetro's required patches.
