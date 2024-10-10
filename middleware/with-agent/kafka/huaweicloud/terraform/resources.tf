variable "region" {
  type        = string
  description = "The region to deploy the Kafka cluster instance."
}

variable "service_id" {
  type        = string
  description = "ID of the service for which the resource is being created."
}

variable "agent_version" {
  type        = string
  description = "version of the agent to be installed in the resources."
}

variable "xpanse_api_endpoint" {
  type        = string
  description = "API from which the agents can pull configuration changes."
}

variable "availability_zone" {
  type        = string
  default     = ""
  description = "The availability zone to deploy the Kafka cluster instance."
}

variable "flavor_id" {
  type        = string
  default     = "s6.large.2"
  description = "The flavor_id of all nodes in the Kafka cluster instance."
}

variable "worker_nodes_count" {
  type        = string
  default     = 3
  description = "The worker nodes count in the Kafka cluster instance."
}

variable "admin_passwd" {
  type        = string
  default     = ""
  description = "The root password of all nodes in the Kafka cluster instance."
}

variable "vpc_name" {
  type        = string
  default     = "kafka-vpc-default"
  description = "The vpc name of all nodes in the Kafka cluster instance."
}

variable "subnet_name" {
  type        = string
  default     = "kafka-subnet-default"
  description = "The subnet name of all nodes in the Kafka cluster instance."
}

variable "secgroup_name" {
  type        = string
  default     = "kafka-secgroup-default"
  description = "The security group name of all nodes in the Kafka cluster instance."
}

terraform {
  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.61.0"
    }
  }
}

provider "huaweicloud" {
  region = var.region
}

data "huaweicloud_availability_zones" "osc-az" {}

data "huaweicloud_vpcs" "existing" {
  name = var.vpc_name
}

data "huaweicloud_vpc_subnets" "existing" {
  name = var.subnet_name
}

data "huaweicloud_networking_secgroups" "existing" {
  name = var.secgroup_name
}

locals {
  availability_zone  = var.availability_zone == "" ? data.huaweicloud_availability_zones.osc-az.names[0] : var.availability_zone
  admin_passwd       = var.admin_passwd == "" ? random_password.password.result : var.admin_passwd
  vpc_id             = length(data.huaweicloud_vpcs.existing.vpcs) > 0 ? data.huaweicloud_vpcs.existing.vpcs[0].id : huaweicloud_vpc.new[0].id
  subnet_id          = length(data.huaweicloud_vpc_subnets.existing.subnets)> 0 ? data.huaweicloud_vpc_subnets.existing.subnets[0].id : huaweicloud_vpc_subnet.new[0].id
  secgroup_id        = length(data.huaweicloud_networking_secgroups.existing.security_groups) > 0 ? data.huaweicloud_networking_secgroups.existing.security_groups[0].id : huaweicloud_networking_secgroup.new[0].id
  resource_random_id = random_id.new.hex
}

resource "huaweicloud_vpc" "new" {
  count = length(data.huaweicloud_vpcs.existing.vpcs) == 0 ? 1 : 0
  name  = var.vpc_name
  cidr  = "192.168.0.0/16"
}

resource "huaweicloud_vpc_eip" "nat_eip" {
  count = length(data.huaweicloud_vpcs.existing.vpcs) == 0 ? 1 : 0
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name       = "test"
    size       = 5
    share_type = "PER"
    charge_mode = "traffic"
  }
}

resource "huaweicloud_vpc_subnet" "new" {
  count      = length(data.huaweicloud_vpcs.existing.vpcs) == 0 ? 1 : 0
  vpc_id     = local.vpc_id
  name       = var.subnet_name
  cidr       = "192.168.10.0/24"
  gateway_ip = "192.168.10.1"
}

resource "huaweicloud_nat_gateway" "kafka_nat_gateway" {
  count      = length(data.huaweicloud_vpcs.existing.vpcs) == 0 ? 1 : 0
  name        = "nat-gateway-basic"
  description = "test for terraform examples"
  spec        = "1"  # Specify NAT Gateway type (1-4)
  vpc_id      = local.vpc_id
  subnet_id   = local.subnet_id
}

resource "huaweicloud_nat_snat_rule" "snat-rule" {
  count      = length(data.huaweicloud_vpcs.existing.vpcs) == 0 ? 1 : 0
  floating_ip_id  = huaweicloud_vpc_eip.nat_eip[count.index].id
  nat_gateway_id  = huaweicloud_nat_gateway.kafka_nat_gateway[count.index].id
  subnet_id      = local.subnet_id
}

resource "huaweicloud_networking_secgroup" "new" {
  count       = length(data.huaweicloud_networking_secgroups.existing.security_groups) == 0 ? 1 : 0
  name        = var.secgroup_name
  description = "Kafka cluster security group"
}

resource "huaweicloud_networking_secgroup_rule" "secgroup_rule_0" {
  count             = length(data.huaweicloud_networking_secgroups.existing.security_groups) == 0 ? 1 : 0
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "121.37.117.211/32"
  security_group_id = local.secgroup_id
}

resource "huaweicloud_networking_secgroup_rule" "secgroup_rule_1" {
  count             = length(data.huaweicloud_networking_secgroups.existing.security_groups) == 0 ? 1 : 0
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2181
  port_range_max    = 2181
  remote_ip_prefix  = "121.37.117.211/32"
  security_group_id = local.secgroup_id
}

resource "huaweicloud_networking_secgroup_rule" "secgroup_rule_2" {
  count             = length(data.huaweicloud_networking_secgroups.existing.security_groups) == 0 ? 1 : 0
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9092
  port_range_max    = 9093
  remote_ip_prefix  = "121.37.117.211/32"
  security_group_id = local.secgroup_id
}

resource "random_id" "new" {
  byte_length = 4
}

resource "random_password" "password" {
  length           = 12
  upper            = true
  lower            = true
  numeric          = true
  special          = true
  min_special      = 1
  override_special = "#%@"
}

resource "huaweicloud_kps_keypair" "keypair" {
  name     = "keypair-kafka-${random_id.new.hex}"
  key_file = "keypair-kafka-${random_id.new.hex}.pem"
}

data "huaweicloud_images_image" "image" {
  name                  = "Ubuntu 22.04 server 64bit"
  most_recent           = true
  enterprise_project_id = "0"
}

resource "huaweicloud_compute_instance" "zookeeper" {
  availability_zone = local.availability_zone
  name              = "kafka-zookeeper-${local.resource_random_id}"
  flavor_id         = var.flavor_id
  security_group_ids = [local.secgroup_id]
  image_id          = data.huaweicloud_images_image.image.id
  key_pair          = huaweicloud_kps_keypair.keypair.name
  network {
    uuid = local.subnet_id
  }
  user_data = templatefile("user-data-script-zookeeper.sh", {
    serviceId         = var.service_id,
    resourceName      = "kafka-zookeeper-${local.resource_random_id}",
    pollingInterval   = 20,
    xpanseApiEndpoint = var.xpanse_api_endpoint,
    agentVersion      = var.agent_version,
    admin_passwd      = local.admin_passwd
  })
}

resource "huaweicloud_compute_instance" "kafka-broker" {
  count             = var.worker_nodes_count
  availability_zone = local.availability_zone
  name              = "kafka-broker-${local.resource_random_id}-${count.index}"
  flavor_id         = var.flavor_id
  security_group_ids = [local.secgroup_id]
  image_id          = data.huaweicloud_images_image.image.id
  key_pair          = huaweicloud_kps_keypair.keypair.name
  network {
    uuid = local.subnet_id
  }
  user_data = templatefile("user-data-script-kafka-broker.sh", {
    serviceId         = var.service_id,
    resourceName      = "kafka-broker-${local.resource_random_id}-${count.index}",
    pollingInterval   = 20,
    xpanseApiEndpoint = var.xpanse_api_endpoint,
    agentVersion      = var.agent_version,
    admin_passwd      = local.admin_passwd
    zookeeperIp       = huaweicloud_compute_instance.zookeeper.access_ip_v4
    brokerId          = count.index
  })
  depends_on = [
    huaweicloud_compute_instance.zookeeper
  ]
}

output "zookeeper_server" {
  value = "${huaweicloud_compute_instance.zookeeper.access_ip_v4}:2181"
}

output "admin_passwd" {
  value = var.admin_passwd == "" ? nonsensitive(local.admin_passwd) : local.admin_passwd
}
