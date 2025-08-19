#!/bin/bash
# =============================================================
#  Kubernetes 1.33 Cluster Setup - Part 1: Common Setup
#  Run this script on ALL nodes (master + worker)
# =============================================================

set -e

echo "==== [Step 1] Disable Swap ===="
sudo swapoff -a
sudo sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab
echo "Swap status:"
free -h

echo "==== [Step 2] Install containerd ===="
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default \
 | sed 's/SystemdCgroup = false/SystemdCgroup = true/' \
 | sed 's|sandbox_image = ".*"|sandbox_image = "registry.k8s.io/pause:3.10"|' \
 | sudo tee /etc/containerd/config.toml > /dev/null
sudo systemctl restart containerd
sudo systemctl enable containerd
echo "Containerd status:"
systemctl status containerd --no-pager

echo "==== [Step 3] Configure kernel modules & sysctl ===="
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
sudo sysctl -w net.ipv4.ip_forward=1
echo "Check kernel modules:"
lsmod | grep br_netfilter || true
echo "Check IP forwarding:"
sysctl net.ipv4.ip_forward

echo "==== [Step 4] Add Kubernetes repository ===="
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key \
 | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' \
 | sudo tee /etc/apt/sources.list.d/kubernetes.list
echo "Repository added:"
cat /etc/apt/sources.list.d/kubernetes.list

echo "==== [Step 5] Install kubeadm, kubelet, kubectl ===="
sudo apt update -y
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet
echo "Check kubeadm version:"
kubeadm version
echo "Check kubectl version:"
kubectl version --client
echo "Check kubelet status:"
systemctl status kubelet --no-pager || true

echo "==== Part 1 Common Setup Complete ===="
