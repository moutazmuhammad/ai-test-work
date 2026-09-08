# =============================================================================
# Accepted CVEs (perl-base is Essential, no upstream fix):
#   CVE-2026-8376  (CRITICAL, CVSS 9.8)
#   CVE-2026-42496 (CRITICAL, CVSS 9.1)
#   CVE-2026-48959 (HIGH, CVSS 7.5)
#   CVE-2026-48962 (HIGH, CVSS 7.3)
#   CVE-2026-42497 (HIGH, CVSS 7.5)
#   CVE-2026-9538  (HIGH, CVSS 7.5)
# =============================================================================

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
FROM docker.io/bitnamilegacy/mysql:8.0.38-debian-12-r1

USER 0

# Fix OS CVEs and purge perl in a single layer.
# perl-base is retained — it provides /usr/bin/perl for bitnami scripts.
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

# Fix Go stdlib CVEs in ini-file
COPY --from=builder /ini-file /opt/bitnami/common/bin/ini-file