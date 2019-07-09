#provider "google" {
#  project = var.gcp_project
#  region  = var.gcp_region
#}


# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE MASTER SERVER
# ---------------------------------------------------------------------------------------------------------------------

module "k8s_master" {
  source = "./modules/k8s-master"

}

# Enable Firewall Rules to open up Specific ports
module "k8s_firewall_rules_master" {
  source = "./modules/k8s-firewall-rules"

}


# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE NODE SERVERS
# ---------------------------------------------------------------------------------------------------------------------

module "k8s-node" {
  source = "./modules/k8s-node"

}

# Enable Firewall Rules to open up Specific ports
module "k8s_firewall_rules_node" {
  source = "./modules/k8s-firewall-rules"

}
