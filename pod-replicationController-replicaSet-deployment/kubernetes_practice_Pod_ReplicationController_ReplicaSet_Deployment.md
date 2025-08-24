# Kubernetes: Pod, ReplicationController, ReplicaSet, Deployment

এই ডকুমেন্টে আমি **Kubernetes-এর চারটি মূল অবজেক্ট** নিয়ে প্র্যাকটিস করেছি:  
- Pod  
- ReplicationController  
- ReplicaSet  
- Deployment  

প্রতিটি YAML ফাইল, তাদের কাজ, আর কমান্ডগুলো এখানে ডকুমেন্ট করা হলো।

---

## 🔹 Pod (`pod.yaml`)

### কী?
Pod হচ্ছে Kubernetes-এর **সবচেয়ে ছোট deployable unit**।  
এর ভিতরে এক বা একাধিক Container রান করতে পারে।  

### YAML:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: declarative-pod-nginx
  labels:
    env: demo
    type: frontend
spec:
  containers:
  - name: nginx-container
    image: nginx:latest
    ports:
    - containerPort: 80
```

### ব্যাখ্যা:
- `kind: Pod` → একটি Pod তৈরি হবে।  
- `metadata.name` → Pod-এর নাম `declarative-pod-nginx`।  
- `labels` → Pod-কে শনাক্ত করার জন্য লেবেল।  
- `containers` → Pod-এর ভেতরে এক বা একাধিক Container।  
- `nginx:latest` ইমেজ ব্যবহার করছে এবং `80` নাম্বার পোর্ট এক্সপোজ করছে।  

👉 Pod সরাসরি ব্যবহার করলে Self-healing নেই। Pod মারা গেলে Kubernetes নিজে থেকে নতুন Pod তৈরি করে না। এজন্য ReplicaSet বা Deployment ব্যবহার করা হয়।

---

## 🔹 ReplicationController (`rc.yml`)

### কী?
ReplicationController (RC) নিশ্চিত করে নির্দিষ্ট সংখ্যক Pod সবসময় রান করছে।  
যদি একটি Pod ক্র্যাশ করে যায়, RC নতুন Pod বানিয়ে দেয়।  

### YAML:
```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: rc-nginx
  labels:
    env: demo
spec:
  replicas: 3
  template:
    metadata:
      labels:
        env: demo
      name : nginx
    spec:
      containers: 
      - name: nginx-container
        image: nginx:latest
        ports:
        - containerPort: 80
```

### ব্যাখ্যা:
- `replicas: 3` → সবসময় 3টা Pod চালাবে।  
- যদি কোনো Pod মারা যায়, সাথে সাথেই নতুন Pod তৈরি হবে।  
- RC পুরানো পদ্ধতি। আধুনিক Kubernetes-এ এর জায়গায় ReplicaSet ব্যবহার হয়।  

---

## 🔹 ReplicaSet (`rs.yml`)

### কী?
ReplicaSet হচ্ছে RC-এর উন্নত সংস্করণ।  
এখানে **Label Selector** ব্যবহার করে কোন Pod ম্যানেজ হবে সেটা নির্দিষ্ট করা যায়।  

### YAML:
```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
  labels:
    env: demo
spec:
  replicas: 3
  selector:
    matchLabels:
      env: demo
  template:
    metadata:
      labels:
        app: nginx
        env: demo
    spec:
      containers:
      - name: nginx-container
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
```

### ব্যাখ্যা:
- `selector.matchLabels` → ReplicaSet শুধু সেই Pod-গুলো ম্যানেজ করবে যাদের label `env: demo`।  
- `replicas: 3` → 3টি Pod সবসময় চলবে।  
- `app: nginx` এবং `env: demo` লেবেল দিয়ে Pod তৈরি হবে।  

👉 ReplicaSet এখনও সরাসরি ইউজ করা হয় না। বরং Deployment এর মাধ্যমে ম্যানেজ করা হয়।  

---

## 🔹 Deployment (`delpoyment-nginx.yml`)

### কী?
Deployment হলো Kubernetes-এ সবচেয়ে বেশি ব্যবহার হওয়া Object।  
এটি **ReplicaSet ম্যানেজ করে** এবং **Rolling Update, Rollback** সাপোর্ট করে।  

### YAML:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
  labels:
    env: demo
spec:
  replicas: 3
  selector:
    matchLabels:
      env: demo
  template:
    metadata:
      labels:
        env: demo
    spec:
      containers:
      - name: nginx-container
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
```

### ব্যাখ্যা:
- `replicas: 3` → সবসময় 3টা Pod থাকবে।  
- Deployment → ReplicaSet → Pods চেইন তৈরি হয়।  
- সহজেই ইমেজ আপডেট করা যায় (`kubectl set image`)।  
- সমস্যা হলে **rollback** করা যায় (`kubectl rollout undo`)।  

👉 Production এ সাধারণত Deployment ব্যবহার করা হয়।  

---

## 🔹 Deployment (Generated via kubectl) (`deploy.yml`)

এটি CLI দিয়ে তৈরি:

```bash
kubectl create deployment nginx-new --image=nginx:1.25-alpine --dry-run=client -o yaml > deploy.yml
```

YAML:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx-new
  name: nginx-new
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-new
  template:
    metadata:
      labels:
        app: nginx-new
    spec:
      containers:
      - image: nginx:1.25-alpine
        name: nginx
```

👉 একদম Minimal Deployment। কেবল একটিমাত্র Replica তৈরি করে।  

---

# Kubernetes: Pod, ReplicationController, ReplicaSet, Deployment

---

## 🧾 Kubectl Command Cheat Sheet (Updated)

| Command | ব্যাখ্যা |
|---------|----------|
| `kubectl get nodes` | ক্লাস্টারের সব নোড দেখায় |
| `kubectl get all` | সব অবজেক্ট (Pods, RS, Deployments, Services) একসাথে দেখায় |
| `kubectl apply -f pod.yaml` | Pod তৈরি/আপডেট করে |
| `kubectl get pods -o wide` | Pods + কোন Node-এ রান করছে তা দেখায় |
| `kubectl describe pod declarative-pod-nginx` | Pod-এর বিস্তারিত তথ্য |
| `kubectl logs <pod-name>` | Pod-এর লগস দেখার জন্য |
| `kubectl exec -it <pod-name> -- /bin/sh` | Pod-এর ভেতরে ঢুকে শেল পাওয়া |
| `kubectl port-forward pod/<pod-name> 8080:80` | লোকাল মেশিনের 8080 → Pod-এর 80 পোর্ট ফরওয়ার্ড |
| `kubectl delete pod declarative-pod-nginx` | Pod ডিলিট করা |

---

### ReplicationController (rc.yml)

| Command | ব্যাখ্যা |
|---------|----------|
| `kubectl apply -f rc.yml` | RC তৈরি/আপডেট করে |
| `kubectl get rc` | সব RC দেখায় |
| `kubectl delete rc rc-nginx` | নির্দিষ্ট RC মুছে ফেলে |

---

### ReplicaSet (rs.yml)

| Command | ব্যাখ্যা |
|---------|----------|
| `kubectl apply -f rs.yml` | RS তৈরি/আপডেট করে |
| `kubectl get rs` | সব ReplicaSet দেখায় |
| `kubectl scale rs/nginx-rs --replicas=5` | RS স্কেল করে ৫ Pod চালাবে |
| `kubectl edit rs/nginx-rs` | সরাসরি YAML এডিট করার সুযোগ |
| `kubectl delete rs/nginx-rs` | RS ডিলিট |

---

### Deployment (delpoyment-nginx.yml, deploy.yml)

| Command | ব্যাখ্যা |
|---------|----------|
| `kubectl apply -f delpoyment-nginx.yml` | Deployment তৈরি/আপডেট |
| `kubectl get deploy` | সব Deployment দেখায় |
| `kubectl set image deploy/nginx-deploy nginx-container=nginx:1.9.1` | নতুন ইমেজে রোলআউট |
| `kubectl rollout status deploy/nginx-deploy` | আপডেট স্ট্যাটাস চেক |
| `kubectl rollout history deploy/nginx-deploy` | পুরোনো ভার্সনের ইতিহাস |
| `kubectl rollout undo deploy/nginx-deploy` | Rollback |
| `kubectl rollout pause deploy/nginx-deploy` | রোলআউট পজ |
| `kubectl rollout resume deploy/nginx-deploy` | রোলআউট আবার চালু |
| `kubectl scale deploy/nginx-deploy --replicas=6` | Replica সংখ্যা বাড়ানো/কমানো |
| `kubectl delete deployment nginx-deploy` | Deployment ডিলিট |

---

## ⚡ Bonus Useful Commands (Tricks)

| Command | কাজ |
|---------|-----|
| `kubectl get pods -w` | লাইভ Pod পরিবর্তন (watch mode) |
| `kubectl top pods` | Pod এর CPU/Memory ইউজেজ (metrics-server লাগবে) |
| `kubectl get events --sort-by=.metadata.creationTimestamp` | ইভেন্ট টাইম অনুযায়ী |
| `kubectl explain deployment.spec` | YAML ফিল্ড ডকুমেন্টেশন |
| `kubectl get pod -o yaml > pod-dump.yaml` | Pod-এর বর্তমান YAML এক্সপোর্ট |
| `kubectl delete all --all` | Namespace-এর সবকিছু ডিলিট |
| `kubectl get ns` | সব Namespace |
| `kubectl config get-contexts` | kubeconfig এর contexts |
| `kubectl config use-context <name>` | Context পরিবর্তন |
| `kubectl create namespace demo` | নতুন namespace তৈরি |
| `kubectl apply -f file.yaml -n demo` | Namespace নির্দিষ্ট করে apply |

---

## 🌐 Visualization (Deployment → RS → Pods)

```mermaid
graph TD
    A[Deployment] --> B[ReplicaSet]
    B --> C1[Pod 1]
    B --> C2[Pod 2]
    B --> C3[Pod 3]

---

📚 এই ডকুমেন্ট পড়ে যে কেউ Kubernetes-এর এই ৪টি অবজেক্ট প্র্যাকটিস করতে পারবে।  
