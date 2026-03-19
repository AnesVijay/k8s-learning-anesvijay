#!/bin/bash
set -euxo pipefail

# Kubernetes Variables
KUBERNETES_VERSION="v1.35"

# Disable swap
sudo swapoff -a

# Keeps the swap off during reboot
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true sudo apt-get update -y

# Create the .conf file to load the modules at bootup
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Install CRI Runtime (containerd)
sudo apt-get update -y
sudo apt-get install -y software-properties-common curl apt-transport-https ca-certificates containerd
sudo systemctl daemon-reload
sudo systemctl enable containerd --now
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
echo "✅ CRI runtime installed successfully"

# Install kubelet, kubectl, and kubeadm
curl -fsSL https://mirror.yandex.ru/mirrors/pkgs.k8s.io/core/stable/$KUBERNETES_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirror.yandex.ru/mirrors/pkgs.k8s.io/core/stable/$KUBERNETES_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubelet kubectl kubeadm

# Prevent automatic updates
sudo apt-mark hold kubelet kubeadm kubectl
sudo apt-get update -y

# Install jq
sudo apt-get install -y jq

# Get the private IP of vm
local_ip=$(hostname -I | awk '{print $1}')

# Configure kubelet
cat > /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
EOF

echo "⚠️ Consider changing SystemdCgroup parameter in /etc/containerd/config.toml to 'true' and restart containerd"