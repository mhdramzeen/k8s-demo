variable "gcp_project" {
  default = "coral-field-243419" # Oregon
}

variable "gcp_region" {
  default = "us-west1" # Oregon
}

variable "instance_name1" {
  default = "k8s-node1"
}

variable "instance_name2" {
  default = "k8s-node2"
}

variable "region1" {
  default = "us-west1-a" # Oregon
}

variable "region2" {
  default = "us-west1-b" # Oregon
}

variable "vm_type1" {
  default = "n1-standard-1"
}

variable "os" {
  default = "rhel-7-v20190618" 
}
