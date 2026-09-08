# ---- Stage 1: rebuild ini-file with Go 1.25.11 -----------------------------
FROM --platform=$BUILDPLATFORM golang:1.25.11 AS builder

ARG TARGETARCH
ARG INI_FILE_VERSION=v1.4.9

RUN git clone --branch ${INI_FILE_VERSION} --depth 1 \
        https://github.com/bitnami/ini-file.git /src/ini-file

WORKDIR /src/ini-file

RUN CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /ini-file .

# ---- Stage 2: patch the base MySQL image ------------------------------------
FROM docker.io/bitnamilegacy/mysql:9.4.0-debian-12-r1

USER 0

# Fix OS CVEs (gnutls28, openssl, glibc, gnupg2) and then purge perl.
# Combined into one RUN so the purge acts on the upgraded packages.
# perl-base is retained — it provides /usr/bin/perl for bitnami scripts.
ARG CACHE_BUST=1
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    dpkg --force-depends --purge \
        perl \
        libperl5.36 \
        perl-modules-5.36 \
        libfile-find-rule-perl \
        libnumber-compare-perl \
        libtext-glob-perl 2>/dev/null; \
    rm -rf /var/lib/dpkg/info/perl* /var/lib/dpkg/info/libperl*

USER 1001

# Fix 23 Go stdlib CVEs in ini-file (Go 1.24.6 -> 1.25.11)
COPY --from=builder /ini-file /opt/bitnami/common/bin/ini-file