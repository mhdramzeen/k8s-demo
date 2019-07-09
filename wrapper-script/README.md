# Wrapper script for Kubernetes cluster setup using Ansible/Terraform template


### Prerequisites:

Setting up Terraform:
```
wget https://releases.hashicorp.com/terraform/0.12.3/terraform_0.12.3_linux_amd64.zip

unzip ./terraform_0.11.13_linux_amd64.zip -d /usr/local/bin/

terraform -v

[root@k8s-master1 k8s-terraform]# terraform -v
Terraform v0.12.3
+ provider.google v2.10.0
```

Setting up Ansible:

```
yum -y install epel-release
yum -y install ansible

[root@k8s-master1 k8s-ansible]# ansible --version
ansible 2.8.1
```

### Infrastructure build using Terraform template:


```
Change directory k8s-demo/wrapper-script/k8s-terraform and run the following terraform commands:

# terraform plan -state=terraform.tfstate
# terraform apply -state=terraform.tfstate

```

### Configuration and service managed using Ansible:


```
Change directory k8s-demo/wrapper-script/k8s-ansible and run the following ansible command:

# ansible-playbook -i inventory  playbooks/k8s-all.yaml

```

Note : We can also run the terraform/ansible in a single script, like fetching the hostname from the terraform using a function and passing to the ansible inventory yaml.
