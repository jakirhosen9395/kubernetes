# Kubernetes 1.33 Cluster Setup (Part 1: Common Setup)

এই ফাইলটি **Kubernetes 1.33 cluster** তৈরির জন্য প্রয়োজনীয় সাধারণ সেটআপ ধাপ (Common Setup) কভার করে।  
প্রতিটি ধাপে দেওয়া হয়েছে:  

👉 (Part 1: Common Setup) ধাপগুলো **সব নোডে (master + worker)** করতে হবে।  

---

## Step 1: Hostname সেট করা
প্রতিটি নোডকে একটি **unique নাম** দিতে হবে, যাতে cluster সহজে node গুলো আলাদা করে চিনতে পারে।

```bash
sudo hostnamectl set-hostname master-node    # Master node এর জন্য
# sudo hostnamectl set-hostname worker-1     # Worker node 1 এর জন্য
# sudo hostnamectl set-hostname worker-2     # Worker node 2 এর জন্য
```

**কেন দরকার:** Cluster-এর মধ্যে node identify করার জন্য। IP দিয়েও সম্ভব, কিন্তু hostname ব্যবহার করলে manage করা সহজ।  
**কাজ কী করে:** সিস্টেমের static hostname পরিবর্তন করে।  
**চেক করার উপায়:**  
```bash
hostnamectl
```
Output এ `Static hostname` নতুন নাম দেখাবে।  

---

## Step 2: Swap Disable করা
Kubernetes swap memory চালু থাকলে কাজ করে না। এজন্য swap বন্ধ করতে হবে।

```bash
# Swap এখনই বন্ধ
sudo swapoff -a

# Swap স্থায়ীভাবে বন্ধ (fstab ফাইলে swap entry comment করা)
sudo sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab
```

**কেন দরকার:** kubelet memory stability এর জন্য swap support করে না।  
**কাজ কী করে:** সিস্টেম RAM-এ swap partition ব্যবহার বন্ধ করে দেয়।  
**চেক করার উপায়:**  
```bash
free -h
```
Output এ `Swap` এর মান **0B** হতে হবে।  

---

## Step 3: Container Runtime (containerd) ইনস্টল করা
Kubernetes container চালাতে runtime ব্যবহার করে। এখানে containerd ব্যবহার করা হচ্ছে।

```bash
# সিস্টেম update
sudo apt update && sudo apt upgrade -y

# containerd ইনস্টল
sudo apt install -y containerd

# containerd config তৈরি + systemd cgroup enable + pause image fix
sudo mkdir -p /etc/containerd
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' | sed 's|sandbox_image = ".*"|sandbox_image = "registry.k8s.io/pause:3.10"|' | sudo tee /etc/containerd/config.toml > /dev/null

# containerd restart এবং enable
sudo systemctl restart containerd
sudo systemctl enable containerd
```

**কেন দরকার:** Kubernetes নিজে container run করতে পারে না, container runtime লাগে। containerd official runtime হিসেবে সমর্থিত।  
**কাজ কী করে:** containerd install করে এবং systemd driver configure করে, যা kubelet এর সাথে compatible।  
**চেক করার উপায়:**  
```bash
systemctl status containerd
```
Output এ `Active: active (running)` দেখাবে।  

---

## Step 4: Kernel Modules এবং Sysctl কনফিগার করা
Pod networking এর জন্য Linux kernel-এ কিছু সেটআপ করতে হয়।

```bash
# Kernel modules স্থায়ীভাবে load করো
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Module load করো
sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl parameter configure করো
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# পরিবর্তনগুলো apply করো
sudo sysctl --system

# নিশ্চিত করো IP forwarding চালু আছে
sudo sysctl -w net.ipv4.ip_forward=1
```

**কেন দরকার:** Pod-to-pod communication এর জন্য iptables কে bridge traffic দেখতে হয় এবং node গুলোতে packet forwarding চালু করতে হয়।  
**কাজ কী করে:** Kernel module load করে এবং network forwarding enable করে।  
**চেক করার উপায়:**  
```bash
lsmod | grep br_netfilter
sysctl net.ipv4.ip_forward
```
- `br_netfilter` module লোড হয়েছে কিনা দেখতে হবে।  
- `net.ipv4.ip_forward` এর মান **1** হতে হবে।  

---

## Step 5: Kubernetes Repository যোগ করা
Ubuntu/Debian default repo তে Kubernetes এর সর্বশেষ version থাকে না। এজন্য অফিসিয়াল repo যোগ করতে হবে।

```bash
# প্রয়োজনীয় প্যাকেজ ইনস্টল
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# GPG keyrings directory তৈরি
sudo mkdir -p /etc/apt/keyrings

# Kubernetes GPG key এবং repository add করো
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

```

**কেন দরকার:** Kubernetes এর অফিসিয়াল repo থেকে সর্বশেষ stable version install করা যাবে।  
**কাজ কী করে:** নতুন apt repo যোগ করে যেখানে Kubernetes packages রাখা আছে।  
**চেক করার উপায়:**  
```bash
cat /etc/apt/sources.list.d/kubernetes.list
```
Output এ Kubernetes repo লাইন দেখা যাবে।  

---

## Step 6: Kubernetes Components ইনস্টল করা
Cluster bootstrap এবং ম্যানেজ করার জন্য kubeadm, kubelet, kubectl ইনস্টল করতে হবে।

```bash
# apt update
sudo apt update

# Kubernetes component install
sudo apt install -y kubelet kubeadm kubectl

# স্বয়ংক্রিয় update রোধ করো
sudo apt-mark hold kubelet kubeadm kubectl

# kubelet enable করো
sudo systemctl enable kubelet
```

**কেন দরকার:**  
- `kubeadm` → cluster init করার টুল।  
- `kubelet` → প্রতিটি node-এ pod চালায়।  
- `kubectl` → cluster manage করার command line tool।  

**কাজ কী করে:** Kubernetes এর তিনটি প্রধান component install করে এবং kubelet auto-start enable করে।  
**চেক করার উপায়:**  
```bash
kubeadm version
kubectl version --client
systemctl status kubelet
```
- `kubeadm` version number দেখাবে।  
- `kubectl` client version দেখাবে।  
- `kubelet` active হবে কিন্তু restart/crashloop করতে পারে (expected, কারণ cluster এখনো init হয়নি)।  

---

# Kubernetes 1.33 Cluster Setup (Part 2: Master Node Setup)

---

## Step 7: Cluster Initialize করা
প্রথমে master node এর IP address বের করতে হবে, তারপর cluster initialize করতে হবে।

```bash
# Master node এর IP address বের করো
ip addr show

# Cluster initialize করো (তোমার master IP বসাও)
sudo kubeadm init --apiserver-advertise-address=<YOUR_MASTER_IP> --pod-network-cidr=192.168.0.0/16
```

**কেন দরকার:** Cluster শুরু করার জন্য control plane তৈরি করতে হবে (API server, etcd, scheduler, controller-manager)।  
**কাজ কী করে:** এই কমান্ড master node কে control-plane বানিয়ে দেয়।  
**চেক করার উপায়:** Output এ একটি **kubeadm join command** আসবে। সেটি worker node এ ব্যবহার করতে হবে।  

---

## Step 8: kubectl Access কনফিগার করা
kubectl যেন master node থেকে cluster এর সাথে কাজ করতে পারে, এজন্য config সেট করতে হবে।

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**কেন দরকার:** kubectl default user context পায় না, তাই admin.conf কপি করে দিতে হয়।  
**কাজ কী করে:** kubeconfig ফাইল user home ডিরেক্টরিতে সেট করে দেয়।  
**চেক করার উপায়:**  
```bash
kubectl get nodes
```
Output এ master node দেখা যাবে (প্রথমে `NotReady` থাকবে, পরে network plugin install এর পর `Ready` হবে)।  

---

## Step 9: Cilium ইনস্টল করা (CNI Plugin)
Pod-to-pod communication এর জন্য একটি Container Network Interface (CNI) plugin দরকার। এখানে **Cilium** ব্যবহার করা হচ্ছে।

```bash
# Cilium CLI version বের করা এবং ডাউনলোড করা
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi

curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Cilium version check
cilium version

# Cilium ইনস্টল with appropiate version.
cilium install --version v1.18.1 #choose from the last command (cilium version)_

# Status check
cilium status
```

**কেন দরকার:** Pod গুলো যেন একে অপরের সাথে communicate করতে পারে।  
**কাজ কী করে:** Cluster এ networking সেটআপ করে।  
**চেক করার উপায়:** `cilium status` চালিয়ে healthy দেখাতে হবে।  

---

## Step 10: Master Node এ Scheduling Allow করা (Optional)
ডিফল্টে master node এ workload schedule হয় না। চাইলে master node এ pod চালানো যাবে।

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

**কেন দরকার:** ছোট cluster এ resources কম থাকে, তাই master node এ workload চালাতে হলে taint remove করতে হয়।  
**চেক করার উপায়:**  
```bash
kubectl describe node master-node | grep Taints
```
যদি কিছু না দেখায়, তাহলে taint remove হয়ে গেছে।  

---

## Step 11: Worker Node Join করানো
Worker node গুলোতে আগে Part 1 এর সব ধাপ শেষ করতে হবে। তারপর master node init এ পাওয়া join command চালাতে হবে।

```bash
# Worker node এ চালাতে হবে (master init output থেকে নেওয়া)
sudo kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
```

**কেন দরকার:** Worker node cluster এ যুক্ত হবে এবং workloads চালাতে পারবে।  
**চেক করার উপায়:**  
```bash
kubectl get nodes
```
সব worker node `Ready` status এ আসবে।  

---

## ✅ Verification
Cluster ঠিকভাবে কাজ করছে কিনা যাচাই করতে:

```bash
# সব নোড ready কিনা দেখো
kubectl get nodes

# সব system pod চলছে কিনা দেখো
kubectl get pods --all-namespaces

# টেস্ট হিসেবে একটি nginx deployment বানাও
kubectl create deployment test-nginx --image=nginx

# Pod গুলো দেখো
kubectl get pods

# টেস্ট শেষ হলে deployment মুছে ফেলো
kubectl delete deployment test-nginx
```

---

## 🔧 Troubleshooting
- **Token Expired:**  
  ```bash
  kubeadm token create --print-join-command
  ```

- **Node Not Ready:**  
  ```bash
  kubectl describe node <node-name>
  sudo journalctl -u kubelet -f
  ```

- **Cluster Reset:**  
  ```bash
  sudo kubeadm reset -f
  sudo rm -rf $HOME/.kube/config /etc/kubernetes/ /var/lib/etcd/
  ```

---

## 🔒 Network Configuration Info
- Required Ports:  
  - Master Node: 6443, 2379-2380, 10250-10252  
  - Worker Nodes: 10250, 30000-32767  

- Network Ranges:  
  - Pod Network CIDR: 192.168.0.0/16  
  - Service Network: 10.96.0.0/12  

---

## ✅ Quick Commands
```bash
kubectl get nodes                           # নোড লিস্ট দেখো
kubectl get pods --all-namespaces           # সব pod দেখো
kubectl create deployment <n> --image=<i>   # নতুন deployment বানাও
kubectl scale deployment <n> --replicas=3   # replicas বাড়াও
kubectl delete deployment <n>               # deployment মুছে ফেলো
```

---

## 🌐 Static IP Configuration (Optional)
কখনও master node কে static IP দিতে হতে পারে।

```bash
ip a show eth0          # বর্তমান IP দেখো / ethernet
ip a show wlp0s20f3          # বর্তমান IP দেখো / wifi
ip route | grep default # gateway address খুঁজে বের করো

sudo nano /etc/netplan/00-installer-config.yaml
```

Example config for Ethernet:
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses: [192.168.121.62/24]   # তোমার বর্তমান IP
      routes:
        - to: default
          via: 192.168.121.1           # তোমার gateway
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]  # Google DNS
```
Example config for WIFI:
```yaml
network:
  version: 2
  renderer: networkd
  wifis:
    wlp0s20f3:
      dhcp4: no
      addresses: [192.168.1.50/24]     # তোমার static IP
      routes:
        - to: default
          via: 192.168.1.1             # Gateway (from ip route)
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]  # DNS servers
      access-points:
        "Your-WiFi-SSID":
          password: "Your-WiFi-Password"
```
Apply config for Ethernet:
```bash
sudo netplan --debug try
sudo netplan apply
ip a show eth0
```
Apply config for WIFI:
```bash
sudo netplan --debug try
sudo netplan apply
ip a show wlp0s20f3

```


---

## 🎯 Summary
Part 2 শেষে master node এ থাকবে:  
- Cluster initialized  
- kubectl configured  
- Cilium networking সেটআপ  
- Worker nodes join করার জন্য command প্রস্তুত  

এখন worker node গুলো cluster এ যুক্ত করতে পারবে।  


## ✅ Summary
এই Common Setup শেষে প্রতিটি node প্রস্তুত হবে:  
- Unique hostname থাকবে  
- Swap বন্ধ থাকবে  
- Container runtime (containerd) চালু থাকবে  
- Kernel networking configured থাকবে  
- Kubernetes tools ইনস্টল হয়ে ready থাকবে  

এরপর master node-এ গিয়ে **Part 2: Cluster Initialization** শুরু করতে হবে।
