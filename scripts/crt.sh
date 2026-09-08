#!/bin/bash
# Usage: ./generate-cert.sh <main-domain> <cert-output-path>
# Example: ./generate-cert.sh 34.128.150.196.nip.io ~/certs

set -e

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <main-domain> <cert-output-path>"
  exit 1
fi

MAIN_DOMAIN=$1
CERT_PATH=$2

mkdir -p "$CERT_PATH/$MAIN_DOMAIN"
cd "$CERT_PATH/$MAIN_DOMAIN"

# ------------------------------
# Create Root CA if not exist
# ------------------------------
if [ ! -f rootCA.key ] || [ ! -f rootCA.crt ]; then
  echo "Generating Root CA..."
  openssl req -x509 -sha256 -days 3650 -nodes -newkey rsa:2048 \
    -subj "/CN=RootCA/O=DevLab/C=GB/L=London" \
    -keyout rootCA.key -out rootCA.crt
fi

# ------------------------------
# Generate Private Key for domain
# ------------------------------
openssl genrsa -out "${MAIN_DOMAIN}.key" 2048

# ------------------------------
# Create CSR config with wildcard
# ------------------------------
cat > csr.conf <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
CN = ${MAIN_DOMAIN}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${MAIN_DOMAIN}
DNS.2 = *.${MAIN_DOMAIN}
EOF

# ------------------------------
# Generate CSR
# ------------------------------
openssl req -new -key "${MAIN_DOMAIN}.key" -out "${MAIN_DOMAIN}.csr" -config csr.conf

# ------------------------------
# Generate certificate signed by Root CA
# ------------------------------
openssl x509 -req -in "${MAIN_DOMAIN}.csr" \
  -CA rootCA.crt -CAkey rootCA.key -CAcreateserial \
  -out "${MAIN_DOMAIN}.crt" -days 365 -sha256 -extfile csr.conf

# ------------------------------
# Create Kubernetes TLS secret
# ------------------------------
kubectl create secret tls gateway-tls \
  --cert="${MAIN_DOMAIN}.crt" \
  --key="${MAIN_DOMAIN}.key" \
  -n gateway --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Certificate and secret created successfully!"
echo "Path: $CERT_PATH/$MAIN_DOMAIN"
echo "- Certificate: ${MAIN_DOMAIN}.crt"
echo "- Key: ${MAIN_DOMAIN}.key"
echo "- Root CA: rootCA.crt"
echo "Use 'curl -k https://${MAIN_DOMAIN}' for testing (self-signed cert)."