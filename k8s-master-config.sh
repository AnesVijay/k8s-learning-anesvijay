#!/bin/bash
set -euxo pipefail

# Variables
NODENAME=$(hostname -s)
POD_CIDR="192.168.0.0/16"
SERVICE_CIDR="10.27.0.0/12"
CALICO_VERSION="v3.31.4"
KUBERNETES_VERSION="v1.35.0"

# Get PUBLIC IP (needed for clouds)
# MASTER_PUBLIC_IP=$(curl ifconfig.me && echo "")
MASTER_PUBLIC_IP=$(hostname -I | awk '{print $1}')
echo "Master IP: $MASTER_PUBLIC_IP"

# Pull required images
sudo kubeadm config images pull

# Initialize kubeadm
sudo kubeadm init \
--control-plane-endpoint="$MASTER_PUBLIC_IP" \
--apiserver-cert-extra-sans="$MASTER_PUBLIC_IP" \
--pod-network-cidr="$POD_CIDR" \
--service-cidr="$SERVICE_CIDR" \
--kubernetes-version="$KUBERNETES_VERSION" \
--node-name "$NODENAME" \
--ignore-preflight-errors=Swap
mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# Install Calico Network Plugin
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/calico.yaml

# Wait for api-server to be up
until kubectl get nodes; do
    echo "Waiting for API server to be available..."
    sleep 5
done
echo "#!/bin/bash" > /tmp/kubeadm_join_cmd.sh
kubeadm token create --print-join-command >> /tmp/kubeadm_join_cmd.sh
chmod +x /tmp/kubeadm_join_cmd.sh