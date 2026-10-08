# Match the patched ESP-IDF toolchain used by .github/workflows/build.yml.
ARG IDF_IMAGE=ghcr.io/darthcloud/idf-blueretro:v5.5.0_2024-12-02
FROM ${IDF_IMAGE}

COPY --chmod=0755 tools/docker-build.sh /usr/local/bin/blueretro-build
USER root
RUN sed -i 's/\r$//' /usr/local/bin/blueretro-build
USER runner
WORKDIR /project
ENTRYPOINT ["/usr/local/bin/blueretro-build"]
CMD ["hw1", "n64"]
