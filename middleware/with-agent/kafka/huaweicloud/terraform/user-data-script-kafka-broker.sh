#!/bin/bash

#
# SPDX-License-Identifier: Apache-2.0
#  SPDX-FileCopyrightText: Huawei Inc.
#

# We must set the password here again since huawei cloud uses userdata to setup root password.
# when we pass a custom userdata script, then the in-built userdata script is not executed.

echo root:${admin_passwd} | sudo chpasswd

# Add Docker's official GPG key:
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
 sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl start docker
sudo systemctl enable docker

private_ip=$(ifconfig | grep -A1 "eth0" | grep 'inet' | awk -F ' ' ' {print $2}'|awk ' {print $1}')
sudo docker run -d --name kafka-server --restart always -p 9092:9092 -p 9093:9093  -e KAFKA_BROKER_ID=${brokerId}  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://$private_ip:9092 -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092 -e ALLOW_PLAINTEXT_LISTENER=yes -e KAFKA_CFG_ZOOKEEPER_CONNECT=${zookeeperIp}:2181 bitnami/kafka:3.3.2


wget -O /tmp/create-agent-service.sh https://raw.githubusercontent.com/eclipse-xpanse/xpanse-agent/refs/heads/main/scripts/create-agent-service.sh

chmod 775 /tmp/create-agent-service.sh

/tmp/create-agent-service.sh --serviceId ${serviceId} --resourceName ${resourceName} --pollingInterval ${pollingInterval} --xpanseApiEndpoint ${xpanseApiEndpoint} --agentVersion ${agentVersion}