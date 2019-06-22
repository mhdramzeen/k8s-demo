# k8s-demo


### Highly available Kubernetes cluster manually using Google Compute Engines:

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









