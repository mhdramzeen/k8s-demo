# k8s-demo


### Highly available Kubernetes cluster setup manually using Google Compute Engines:

First we configure hostnames for all members of cluster. Those will be k8s-master1, k8s-master2 and k8s-master3 for our masters and k8s-node and k8s-node2 for nodes:
```
hostnamectl set-hostname k8s-master1
```

Repeat this on all other hosts

Next we need to make sure that those hostnames are in /etc/hosts on all members. After editing it should look like below:

```
#k8s master
10.138.0.14 k8s-master1
10.138.0.15 k8s-master2
10.138.0.16 k8s-master3

#k8s nodes
k8s-node 10.138.0.18
k8s-node2 10.138.0.19
```

Enable kernel module and make sure it is loaded on boot:

```
Setup required sysctl params, these persist across reboots.
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

Load new parameters:
sysctl --system
```

Install Docker on all hosts

```
# Install Docker CE
## Set up the repository
### Install required packages.
yum install yum-utils device-mapper-persistent-data lvm2

### Add Docker repository.
yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo

## Install Docker CE.
yum update && yum install docker-ce-18.06.3.ce
systemctl enable docker
systemctl start docker
```

Install kubeadm, kubelet and kubectl on masters/nodes:

```
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF

# Set SELinux in permissive mode (effectively disabling it)
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable kubelet
```
```
[root@k8s-master1 ramzeen_mhd]# kubelet --version && kubeadm version &&  kubectl version
Kubernetes v1.14.3
kubeadm version: &version.Info{Major:"1", Minor:"14", GitVersion:"v1.14.3", GitCommit:"5e53fd6bc17c0dec8434817e69b04a25d8ae0ff0", GitTreeState:"clean", BuildDate:"2019-06-06T01:41:54Z", GoVersion:"go1.12.5", Compiler:"gc", Platform:"linux/amd64"}
Client Version: version.Info{Major:"1", Minor:"14", GitVersion:"v1.14.3", GitCommit:"5e53fd6bc17c0dec8434817e69b04a25d8ae0ff0", GitTreeState:"clean", BuildDate:"2019-06-06T01:44:30Z", GoVersion:"go1.12.5", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"14", GitVersion:"v1.14.3", GitCommit:"5e53fd6bc17c0dec8434817e69b04a25d8ae0ff0", GitTreeState:"clean", BuildDate:"2019-06-06T01:36:19Z", GoVersion:"go1.12.5", Compiler:"gc", Platform:"linux/amd64"}
```

Setting up a Nginx Loadbalancer:

```
## Creating a directory
mkdir /etc/nginx
```
```
## Adding and editing nginx configuration file /etc/nginx/nginx.conf

events { }

stream {
    upstream stream_backend {
        least_conn;
        # REPLACE WITH master0 IP
        server 10.138.0.14:6443;
        # REPLACE WITH master1 IP
        server 10.138.0.15:6443;
        # REPLACE WITH master2 IP
        server 10.138.0.16:6443;
    }

    server {
        listen        6443;
        proxy_pass    stream_backend;
        proxy_timeout 3s;
        proxy_connect_timeout 1s;
    }
}
```
```
## Starting Nginx

docker run --name proxy \
    -v /etc/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
    -p 6443:6443 \
    -d nginx
``` 

Initialize cluster on first master:

```
Create kubeadm YAML configuration file. Let’s call it kubeadm.yml:

apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: stable
apiServer:
  certSANs:
  - "10.138.0.17"
controlPlaneEndpoint: "10.138.0.17:6443"

kubeadm init --config=kubeadm.yml
```

Copy the certificate and deploy in other masters:

```
tar zcvf k8scerts.tar.gz /etc/kubernetes/admin.conf /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/ca.key /etc/kubernetes/pki/sa.key /etc/kubernetes/pki/sa.pub /etc/kubernetes/pki/front-proxy-ca.crt /etc/kubernetes/pki/front-proxy-ca.key /etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/etcd/ca.key

tar xvf k8scerts.tar.gz -C /
```

Join the other masters to the cluster using kubeadm:

```
kubeadm join 10.138.0.17:6443 --token 0f8hnw.ovzrn846yu51s9f4 \
    --discovery-token-ca-cert-hash sha256:633a5eef17da872379329c7c2bf593cb9df5f1e2b19cf298c9a78180f2ac145a \
    --experimental-control-plane
```

Join the nodes to the cluster using kubeadm:
```
kubeadm join 10.138.0.17:6443 --token 0f8hnw.ovzrn846yu51s9f4 \
    --discovery-token-ca-cert-hash sha256:633a5eef17da872379329c7c2bf593cb9df5f1e2b19cf298c9a78180f2ac145a
```

```
[root@k8s-master1 ramzeen_mhd]# kubectl get nodes
NAME          STATUS   ROLES    AGE     VERSION
k8s-master1   Ready    master   4d13h   v1.14.3
k8s-master2   Ready    master   4d12h   v1.14.3
k8s-master3   Ready    master   4d12h   v1.14.3
k8s-node      Ready    <none>   3d15h   v1.14.3
k8s-node2     Ready    <none>   17h     v1.14.3

[root@k8s-master1 ramzeen_mhd]# kubectl get pods -n kube-system | grep apiserver
kube-apiserver-k8s-master1            1/1     Running   28         4d13h
kube-apiserver-k8s-master2            1/1     Running   6          4d12h
kube-apiserver-k8s-master3            1/1     Running   7          4d12h
```


### Deploy guest-book application

```
## Creating a namespace for deploying app:
kubectl create ns dev-app
```

```
## Created Redis master and slave:

kubectl apply -f guestbook/redis-master-deployment.yaml
kubectl apply -f guestbook/redis-master-service.yaml
kubectl apply -f guestbook/redis-slave-deployment.yaml
kubectl apply -f guestbook/redis-slave-service.yaml

## Creating frontend
kubectl apply -f guestbook/frontend-deployment.yaml
kubectl apply -f guestbook/frontend-service.yaml
```

```
[root@k8s-master1 k8s-demo]# kubectl get pods -n dev-app
NAME                           READY   STATUS    RESTARTS   AGE
frontend-69859f6796-2gwzc      1/1     Running   2          17h
frontend-69859f6796-ph5vn      1/1     Running   1          17h
frontend-69859f6796-qztv7      1/1     Running   2          17h
redis-master-596696dd4-ghvmh   1/1     Running   1          17h
redis-slave-6bb9896d48-gtq64   1/1     Running   1          17h
redis-slave-6bb9896d48-rdk5f   1/1     Running   1          17h

[root@k8s-master1 k8s-demo]# kubectl get service -n dev-app
NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
frontend       NodePort    10.107.14.244   <none>        80:31831/TCP   3d15h
redis-master   ClusterIP   10.104.231.58   <none>        6379/TCP       3d15h
redis-slave    ClusterIP   10.100.144.20   <none>        6379/TCP       3d15h
```

### Install and configure Helm in Kubernetes

Download and extracted https://github.com/helm/helm/releases/tag/v2.12.3
```
Unpack it (helm-v2.12.3-linux-amd64.tar.gz)
mv linux-amd64/helm /usr/local/bin/helm
PATH=$PATH:/usr/local/bin
Run 'helm init' to configure helm.

## Create the tiller serviceaccount:

kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'      
helm init --service-account tiller --upgrade
```

```
[root@k8s-master1 ~]# helm version
Client: &version.Version{SemVer:"v2.12.3", GitCommit:"eecf22f77df5f65c823aacd2dbd30ae6c65f186e", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.12.3", GitCommit:"eecf22f77df5f65c823aacd2dbd30ae6c65f186e", GitTreeState:"clean"}
```















