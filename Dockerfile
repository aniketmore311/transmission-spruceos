# Reproducible cross-build environment for a fully static aarch64
# transmission-daemon. Host is x86_64; target is aarch64-linux-musl.
#
# This image contains the musl.cc cross toolchain plus statically built OpenSSL
# and libcurl (the only external deps Transmission 4.x needs). Building
# Transmission itself is done at `docker run` time via build-transmission.sh,
# so a new Transmission release does not require rebuilding this image.
FROM debian:bookworm-slim

ARG MUSL_TOOLCHAIN_URL
ARG MUSL_TOOLCHAIN_SHA256
ARG OPENSSL_VERSION
ARG OPENSSL_SHA256
ARG CURL_VERSION
ARG CURL_SHA256

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        ninja-build \
        pkg-config \
        curl \
        ca-certificates \
        xz-utils \
        file \
        perl \
        python3 \
    && rm -rf /var/lib/apt/lists/*

COPY scripts/build-toolchain.sh /scripts/build-toolchain.sh
RUN chmod +x /scripts/build-toolchain.sh && /scripts/build-toolchain.sh

COPY scripts/build-deps.sh /scripts/build-deps.sh
RUN chmod +x /scripts/build-deps.sh && /scripts/build-deps.sh

COPY scripts/ /scripts/
COPY cmake/ /cmake/
RUN chmod +x /scripts/*.sh

ENV PATH="/opt/aarch64-linux-musl-cross/bin:${PATH}"
ENV OPENSSL_VERSION="${OPENSSL_VERSION}"
ENV CURL_VERSION="${CURL_VERSION}"

ENTRYPOINT ["/scripts/build-transmission.sh"]
