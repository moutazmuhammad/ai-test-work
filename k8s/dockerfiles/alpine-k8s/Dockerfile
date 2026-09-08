# =============================================================================
# Minimal kubectl image — replaces alpine/k8s which bundles 20+ unused tools
# (kustomize, eksctl, helm, etc.) each carrying their own CVEs.
#
# Only kubectl + sh are needed by the SeaweedFS volume resize hook.
# =============================================================================

FROM alpine:3.24

ARG TARGETARCH
ARG KUBECTL_VERSION=v1.33.13

RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache curl ca-certificates && \
    curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
    apk del curl && \
    rm -rf /var/cache/apk/*

# Non-root user
RUN adduser -D -u 1000 kubectl
USER 1000

ENTRYPOINT ["/bin/sh"]


# docker buildx build --platform linux/amd64,linux/arm64 -t europe-west1-docker.pkg.dev/vf-grp-aib-dev-mirror/aib-plus-images/alpine-k8s:aibplus-v1 --push .

# docker push europe-west1-docker.pkg.dev/vf-grp-aib-dev-mirror/aib-plus-images/alpine-k8s:aibplus-v1