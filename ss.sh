#!/bin/bash
# filename: ss
#
# 地址：https://github.com/beautyonly/QQ-docker/blob/master/ss.sh
#
# set -e
#
# * 启动:   ./ss start
# * 停止:   ./ss stop
# * 状态:  ./ss status
# * 给命令行加载代理环境变量: eval $(./ss env)
# * 卸载命令行的代理环境变量: eval $(./ss env --unset)
#
# 使用该脚本的前提条件
#
# 1、机器上需要已经装好了 Docker 以及 docker-machine
# 2、如果需要配置 DNS，则需要安装 doctl： https://github.com/digitalocean/doctl ，mac 下 brew 就可以安装
# 3、需要安装 vultr 的 docker-machine 驱动： https://github.com/janeczku/docker-machine-vultr
# 4、Vultr 的 API Key 需要在 VULTR_API_KEY 环境变量中
#
#   export VULTR_API_KEY=你的API_KEY
#
# 5、由于Vultr默认为 RancherOS，所以还需要设置为 Ubuntu 16.04 LTS
#
#   export VULTR_OS=215
#
# 6、如果需要 DNS 配置，则也需要有 Digtial Ocean 的 API TOKEN 在环境变量 DIGITALOCEAN_ACCESS_TOKEN 中
#
#   export DIGITALOCEAN_ACCESS_TOKEN=你的DO_ACCESS_TOKEN
#

DOMAIN=lab99.org
NAME=ss
PORT=443
MODE=aes-256-gcm
TOKEN=dockerrocks

function create_machine() {
  local name=$1
  shift
  # Create a docker host
  docker-machine create -d vultr --vultr-region-id=25 $name
  docker-machine ls | grep $name

  # Prepare the machine
  docker-machine ssh $name  << EOF
  apt-get update
  apt-get install --install-recommends -y linux-generic-hwe-16.04 
  apt-get dist-upgrade -y
  echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
  echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
  reboot
EOF

  sleep 20

  docker-machine ssh $name "sysctl net.ipv4.tcp_available_congestion_control; lsmod | grep bbr"
}

function remove_machine() {
  local name=$1
  # Simply remove the machine
  docker-machine rm -y $name
  echo "Removed docker host: $name"
}

function create_dns_record() {
  local name=$1
  local domain=$2

  # Get IP of the docker host
  ip=$(docker-machine ip $name)
  if [ -z "$ip" ]; then
    echo "Cannot found docker-machine: $name"
    return 1
  fi

  # Create DNS record for constant usage
  local id=`doctl compute domain records list $domain | grep $name | cut -d' ' -f1`
  if [ -z "$id" ]; then
    # create one
    id=`doctl compute domain records create $domain --record-name=$name --record-data=$ip --record-type=A | grep $name | cut -d' ' -f1`
    if [ -z "$id" ]; then
      echo "Failed to create the $name.$domain records"
    else
      echo "Created DNS record: $name.$domain => $ip"
    fi
  else
    # update the existing one
    doctl compute domain records update $domain --record-id=$id --record-data=$ip
    echo "Updated DNS record: $name.$domain => $ip"
  fi
}

function remove_dns_record() {
  local name=$1
  local domain=$2

  # Remove the dns record
  local id=`doctl compute domain records list $domain | grep $name | cut -d' ' -f1`
  if [ -z "$id" ]; then
    echo "DNS record '$name.$domain' does not exist"
  else
    doctl compute domain records delete lab99.org "$id" -f
    echo "DNS record '$name.$domain' removed"
  fi
}

function create_hosts_record() {
  local name=$1
  local domain=$2

  # Get IP of the docker host
  ip=$(docker-machine ip $name)
  if [ -z "$ip" ]; then
    echo "Cannot found docker-machine: $name"
    return 1
  fi

  # Remove the host record if it exists
  remove_hosts_record $name $domain

  # Append record to /etc/hosts
  echo "$ip   $name.$domain" | sudo tee -a /etc/hosts
}

function remove_hosts_record() {
  local name=$1
  local domain=$2

  if grep -q $name.$domain /etc/hosts; then
    sudo sed -i "/$name.$domain/d" /etc/hosts
  fi
}

function start_proxy() {
  local name=$1
  local port=$2
  local mode=$3
  local token=$4

  # Start Proxy
  eval $(docker-machine env $name)
  docker run --name $name -d -p $port:$port\
    mritd/shadowsocks \
      -s "-s 0.0.0.0 -p $port -m $mode -k $token --fast-open" 
}

function start() {
  create_machine $NAME
  # create_dns_record $NAME $DOMAIN
  create_hosts_record $NAME $DOMAIN
  start_proxy $NAME $PORT $MODE $TOKEN
}

function stop() {
  remove_machine $NAME
  # remove_dns_record $NAME $DOMAIN
  remove_hosts_record $NAME $DOMAIN
}

function status() {
  docker-machine ls --filter "name=$NAME"
  eval $(docker-machine env $NAME)
  docker ps -f "name=$NAME" -a
  docker logs $@ $NAME
}

function environment() {
  if [ "$1" = "--unset" ]; then
    # Unset all proxy env
    echo unset http_proxy
    echo unset https_proxy
    echo unset HTTP_PROXY
    echo unset HTTPS_PROXY
    echo unset all_proxy
    echo "# Run: eval \$($0 env --unset)"
  else
    # Set proxy env
    http_proxy=socks5h://127.0.0.1:1086
    echo export http_proxy=socks5h://127.0.0.1:1086
    echo export https_proxy=$http_proxy
    echo export HTTP_PROXY=$http_proxy
    echo export HTTPS_PROXY=$http_proxy
    echo export all_proxy=$http_proxy
    echo "# Run: eval \$($0 env)"
  fi
}

command=$1
shift

case $command in
  start)   start ;;
  stop)    stop ;;
  status)  status ;;
  env)     environment $@ ;;
  *)       echo "Usage: $0 (start|stop|status|env)" ;;
esac
