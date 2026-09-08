# ---- Stage 1: rebuild weed with patched Go and thrift dependency ------------
FROM --platform=$BUILDPLATFORM golang:1.25.11 AS builder

ARG TARGETARCH
ARG SEAWEEDFS_VERSION=4.35

RUN git clone --branch ${SEAWEEDFS_VERSION} --depth 1 \
        https://github.com/seaweedfs/seaweedfs.git /src/seaweedfs

WORKDIR /src/seaweedfs

# Only swap the thrift version in the existing replace directive (0.22.0 -> 0.23.0).
# Do NOT remove the replace or run go mod tidy — that cascades transitive dep changes.
RUN sed -i 's|replace github.com/apache/thrift => github.com/apache/thrift v0.22.0|replace github.com/apache/thrift => github.com/apache/thrift v0.23.0|' go.mod && \
    go mod download github.com/apache/thrift@v0.23.0

RUN CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w -X github.com/seaweedfs/seaweedfs/weed/util.COMMIT=patched-thrift" \
    -o /usr/bin/weed ./weed

# ---- Stage 2: drop the patched binary into the base SeaweedFS image --------
FROM chrislusf/seaweedfs:4.35

COPY --from=builder /usr/bin/weed /usr/bin/weed