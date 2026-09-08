# ---- Stage 1: rebuild scuttle with Go >= 1.26.4 and patched deps -----------
FROM --platform=$BUILDPLATFORM golang:1.26.4 AS builder

ARG TARGETARCH
ARG SCUTTLE_VERSION=v1.3.7

RUN git clone --branch ${SCUTTLE_VERSION} --depth 1 \
        https://github.com/redboxllc/scuttle.git /src/scuttle

WORKDIR /src/scuttle

# Upgrade golang.org/x/text to fix CVE-2021-38561 (requires >= 0.3.7)
RUN go get golang.org/x/text@latest && go mod tidy && go mod vendor

RUN CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /scuttle .

# ---- Stage 2: drop the patched binary into the base Redis image ------------
# sha-257a004fe2c0
FROM bitnami/os-shell:latest 

COPY --from=builder /scuttle /opt/bitnami/common/bin/scuttle