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

Deploy overlay network

```
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
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
## Creating Redis master and slave:

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


### Setup and configure Prometheus and Grafana

```
# Creating namespace for the monitoring tool
kubect create ns monitoring
```
```
## Create helm service account
kubectl apply -f helm-rbac.yaml
helm init --service-account helm 
```

```
Installing Prometheus and Grafana using helm
helm install --name kube-prometheus prometheus-grafana/helm/prometheus -f prometheus-grafana/values.yaml --namespace monitoring
helm install --name kube-grafana prometheus-grafana/helm/grafana -f prometheus-grafana/values.yaml --namespace monitoring
```

```
## Adding nginx configuration to make grafana accessible via loadbalancer

    upstream stream_backend2 {
        least_conn;
        # REPLACE WITH master0 IP
        server 10.138.0.14:30000;
    }
    
    server {
        listen        3000;
        proxy_pass    stream_backend2;
        proxy_timeout 3s;
        proxy_connect_timeout 1s;
    }
```
```
[root@k8s-master1 prometheus-grafana]# kubectl get pods -n monitoring
NAME                                     READY   STATUS    RESTARTS   AGE
alertmanager-7b6496fcf4-xt8rz            1/1     Running   1          18h
grafana-774446fd6c-7qk7f                 2/2     Running   16         18h
node-exporter-gxldt                      1/1     Running   2          17h
node-exporter-lgnd7                      1/1     Running   5          2d12h
prometheus-deployment-5644588bfd-v2j25   1/1     Running   1          18h

[root@k8s-master1 k8s-demo]# kubectl get service -n monitoring
NAME             TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
alertmanager     ClusterIP   10.101.128.196   <none>        9093/TCP         2d12h
grafana          NodePort    10.104.181.100   <none>        3000:30000/TCP   2d11h
prometheus-svc   ClusterIP   10.97.218.155    <none>        9090/TCP         2d12h

```

### Setup log analysis using Elasticsearch, Fluentd, Kibana

```
## Installing Elastisearch, fluentd and Kibana 
kubectl create -f fluentd-elasticsearch/es-statefulset.yaml
kubectl create -f fluentd-elasticsearch/es-service.yaml
kubectl create -f fluentd-elasticsearch/fluentd-es-configmap.yaml
kubectl create -f fluentd-elasticsearch/fluentd-es-ds.yaml
kubectl create -f fluentd-elasticsearch/kibana-deployment.yaml
kubectl create -f fluentd-elasticsearch/kibana-service.yaml
```
```
## Adding nginx configuration to make kibana accessible via loadbalancer

    upstream stream_backend3 {
        least_conn;
        # REPLACE WITH master0 IP
        server 10.138.0.14:30010;
    }
    
    server {
        listen        5601;
        proxy_pass    stream_backend3;
        proxy_timeout 3s;
        proxy_connect_timeout 1s;
    }
```    
```
[root@k8s-master1 fluentd-elasticsearch]# kubectl get pods -n kube-system | grep elasticsearch
elasticsearch-logging-0               1/1     Running   2          17h
elasticsearch-logging-1               1/1     Running   1          17h
[root@k8s-master1 fluentd-elasticsearch]# kubectl get pods -n kube-system | grep fluentd
fluentd-es-v2.5.2-67ck9               1/1     Running   3          17h
fluentd-es-v2.5.2-dcqlh               1/1     Running   1          17h
[root@k8s-master1 fluentd-elasticsearch]# kubectl get pods -n kube-system | grep kibana
kibana-logging-f4d99b69f-5pw8p        1/1     Running   1          18h

kubectl get service -n kube-system | grep -v "kube-dns\|prometheus-operator-kubelet\|tiller-deploy"
NAME                          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                  AGE
elasticsearch-logging         ClusterIP   10.107.107.81    <none>        9200/TCP                 18h
kibana-logging                NodePort    10.100.132.187   <none>        5601:30010/TCP           18h
```


### Blue/Green Deplyment

```
# Creating a namespace for the blue green deployment
kubect create ns monitoring
```
```
# Creating blue deployment
kubectl apply -f blue-green-deployment/blue.yaml -n blue-green-deployment

[root@k8s-master1 k8s-demo]# kubectl get pods -n blue-green-deployment
NAME                          READY   STATUS    RESTARTS   AGE
nginx-1.10-547948f549-26r5v   1/1     Running   0          20s
nginx-1.10-547948f549-f52br   1/1     Running   0          20s
nginx-1.10-547948f549-gq2tg   1/1     Running   0          20s

# Creating service for blue deployment:
k apply -f blue-green-deployment/blue-service.yaml -n blue-green-deployment

[root@k8s-master1 k8s-demo]# kubectl get svc -n blue-green-deployment
NAME    TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
nginx   LoadBalancer   10.107.51.64   <pending>     80:31349/TCP   11s

# Testing the nginx service to check the version:
[root@k8s-master1 k8s-demo]# curl -s http://10.107.51.64/version | grep nginx
<hr><center>nginx/1.10.3</center>
```

```
# Creating green deployment, but service is still pointing to blue deployment:
kubectl apply -f blue-green-deployment/green.yaml -n blue-green-deployment

[root@k8s-master1 k8s-demo]# kubectl get pods -n blue-green-deployment
NAME                          READY   STATUS    RESTARTS   AGE
nginx-1.10-547948f549-26r5v   1/1     Running   0          112s
nginx-1.10-547948f549-f52br   1/1     Running   0          112s
nginx-1.10-547948f549-gq2tg   1/1     Running   0          112s
nginx-1.11-848b9b487-2k4xw    1/1     Running   0          11s
nginx-1.11-848b9b487-pmhw5    1/1     Running   0          11s
nginx-1.11-848b9b487-v5tdt    1/1     Running   0          11s

# Updating the service, now it will point to green:

kubectl apply -f green-blue-green-deployment/service.yaml -n blue-green-deployment

[root@k8s-master1 k8s-demo]# kubectl get svc -n blue-green-deployment
NAME    TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
nginx   LoadBalancer   10.107.51.64   <pending>     80:31349/TCP   92s

# New version of nginx is serving traffic
[root@k8s-master1 k8s-demo]# curl -s http://10.107.51.64/version | grep nginx
<hr><center>nginx/1.11.13</center>
```

### Canary Deplyment

```
# Creating a namespace for the canary deployment
kubect create ns canary-deployment
```

```
# Creating canary deployment
kubectl apply -f canary-deployment/hello.yaml -n canary-deployment
kubectl apply -f canary-deployment/hello-canary.yaml -n canary-deployment

# Two deployments, hello and hello-canary:
[root@k8s-master1 k8s-demo]# kubectl get deployment -n canary-deployment
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
hello          3/3     3            3           17m
hello-canary   1/1     1            1           9m33s

[root@k8s-master1 k8s-demo]# kubectl get pods -n canary-deployment
NAME                            READY   STATUS    RESTARTS   AGE
hello-56ff65f9bf-b2w8m          1/1     Running   0          11m
hello-56ff65f9bf-w4n5g          1/1     Running   0          11m
hello-56ff65f9bf-w54cj          1/1     Running   0          8m
hello-canary-6c8f9cc6fd-rz4w4   1/1     Running   0          31s

# Adding hello servic which match in both the deployment

[root@k8s-master1 k8s-demo]# kubectl get svc -n canary-deployment
NAME    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
hello   ClusterIP   10.110.180.80   <none>        80/TCP    11s
[root@k8s-master1 k8s-demo]# while true; do curl -ks https://10.110.180.80/version; sleep 1; done

# Please see the ratio of requests server by the deployments:
[root@k8s-master1 k8s-demo]# while true; do curl -ks http://10.110.180.80/version; sleep 1; done
{"version":"1.0.0"}
{"version":"2.0.0"}
{"version":"1.0.0"}
{"version":"1.0.0"}
{"version":"2.0.0"}
{"version":"1.0.0"}
{"version":"1.0.0"}
{"version":"2.0.0"}
{"version":"1.0.0"}
{"version":"1.0.0"}
{"version":"1.0.0"}
{"version":"1.0.0"}
{"version":"2.0.0"}
{"version":"1.0.0"}
{"version":"1.0.0"}
{"version":"1.0.0"}
{"version":"1.0.0"}
{"version":"1.0.0"}
{"version":"1.0.0"}
{"version":"1.0.0"}
{"version":"1.0.0"}
{"version":"2.0.0"}

```

### Helm to deploy the application on Kubernetes Cluster from CI server

We can use this jenkins pipeline structure for acheiving CI/CD using helm , for deploying the application application

[Jenkinsfile](https://github.com/mhdramzeen/k8s-demo/blob/master/Jenkinsfile)
