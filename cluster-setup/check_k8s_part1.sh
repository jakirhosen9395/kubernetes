#!/bin/bash
# =============================================================
#  Kubernetes 1.33 Cluster Setup - Part 1 Verification Script
#  Run this script on ALL nodes (master + worker) AFTER setup
# =============================================================

echo "==== [Check 1] Swap Disabled ===="
if free -h | grep -q "0B"; then
  echo "[OK] Swap is disabled."
else
  echo "[ERROR] Swap is still enabled! Please disable it."
fi

echo "==== [Check 2] Containerd Running ===="
if systemctl is-active --quiet containerd; then
  echo "[OK] Containerd is running."
else
  echo "[ERROR] Containerd is not running."
fi

echo "==== [Check 3] Kernel Modules Loaded ===="
if lsmod | grep -q br_netfilter && lsmod | grep -q overlay; then
  echo "[OK] br_netfilter and overlay modules are loaded."
else
  echo "[ERROR] Required kernel modules missing."
fi

echo "==== [Check 4] Sysctl Parameters ===="
IP_FORWARD=$(sysctl net.ipv4.ip_forward | awk '{print $3}')
BR_IPTABLES=$(sysctl net.bridge.bridge-nf-call-iptables | awk '{print $3}')
if [ "$IP_FORWARD" -eq 1 ] && [ "$BR_IPTABLES" -eq 1 ]; then
  echo "[OK] Sysctl parameters set correctly."
else
  echo "[ERROR] Sysctl parameters not configured properly."
fi

echo "==== [Check 5] Kubernetes Repo Added ===="
if grep -q "pkgs.k8s.io/core:/stable:/v1.33" /etc/apt/sources.list.d/kubernetes.list; then
  echo "[OK] Kubernetes repo is configured."
else
  echo "[ERROR] Kubernetes repo not found."
fi

echo "==== [Check 6] Kubernetes Tools Installed ===="
if command -v kubeadm >/dev/null 2>&1 && command -v kubectl >/dev/null 2>&1; then
  echo "[OK] kubeadm and kubectl are installed."
  echo "kubeadm version: $(kubeadm version -o short)"
  echo "kubectl version: $(kubectl version --client )"
else
  echo "[ERROR] kubeadm and/or kubectl not installed."
fi

echo "==== [Check 7] Kubelet Status ===="
if systemctl is-enabled --quiet kubelet; then
  echo "[OK] Kubelet service is enabled."
else
  echo "[ERROR] Kubelet service is not enabled."
fi

echo "==== Verification Complete ===="
