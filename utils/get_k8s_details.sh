#!/bin/bash

# Prompt the user for the desired username (Common Name for the certificate)
read -p "Enter the desired username for the client certificate: " USERNAME

# Prompt the user for the desired kubeconfig file name (default: ~/.kube/config)
read -p "Enter the kubeconfig file path [default: ~/.kube/config]: " KUBECONFIG_PATH
KUBECONFIG_PATH=${KUBECONFIG_PATH:-~/.kube/config}

# Define destination directory
DEST_DIR=~/certs

# Create destination directory if it doesn't exist
mkdir -p $DEST_DIR

# Copy the CA certificate
cp /etc/kubernetes/pki/ca.crt $DEST_DIR

# Generate a new private key
echo "Generating a new private key..."
openssl genrsa -out $DEST_DIR/client.key 2048
echo "Private key saved to $DEST_DIR/client.key"

# Generate a Certificate Signing Request (CSR)
echo "Generating a Certificate Signing Request (CSR)..."
openssl req -new -key $DEST_DIR/client.key -out $DEST_DIR/client.csr -subj "/CN=$USERNAME"
echo "CSR saved to $DEST_DIR/client.csr"

# Sign the CSR with the Kubernetes CA to create the client certificate
echo "Signing the CSR with the Kubernetes CA..."
sudo openssl x509 -req -in $DEST_DIR/client.csr -CA $DEST_DIR/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out $DEST_DIR/client.crt -days 365 -sha256
echo "Client certificate saved to $DEST_DIR/client.crt"

# Verify the files
echo "Copied and generated certificates in $DEST_DIR:"
ls -l $DEST_DIR

# Verify contents of the CA certificate
echo "Verifying CA Certificate..."
openssl x509 -in $DEST_DIR/ca.crt -text -noout

# Verify contents of the Client certificate
echo "Verifying Client Certificate..."
openssl x509 -in $DEST_DIR/client.crt -text -noout

# Clean up CSR file as it's no longer needed
rm $DEST_DIR/client.csr

# Set up the kubeconfig file
echo "Setting up the kubeconfig file at $KUBECONFIG_PATH..."

kubectl config set-cluster kubernetes-cluster \
  --certificate-authority=$DEST_DIR/ca.crt \
  --embed-certs=true \
  --server=https://master-node:6443 \
  --kubeconfig=$KUBECONFIG_PATH

kubectl config set-credentials $USERNAME \
  --client-certificate=$DEST_DIR/client.crt \
  --client-key=$DEST_DIR/client.key \
  --embed-certs=true \
  --kubeconfig=$KUBECONFIG_PATH

kubectl config set-context $USERNAME@kubernetes-cluster \
  --cluster=kubernetes-cluster \
  --user=$USERNAME \
  --kubeconfig=$KUBECONFIG_PATH

kubectl config use-context $USERNAME@kubernetes-cluster --kubeconfig=$KUBECONFIG_PATH

echo "Kubeconfig file $KUBECONFIG_PATH has been set up with the new client certificate."
