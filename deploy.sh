#!/bin/bash

# Allowed service names
allowed_services=(
  barbican
  cinder
  glance
  heat
  horizon
  keystone
  libvirt
  magnum
  mariadb
  memcached
  neutron
  nova
  octavia
  openvswitch
  ovn
  placement
  swift
)

OVERRIDES_DIR=$pwd

values_dir=values_overrides

default_helm_args=(
  $values_dir/domain
  $values_dir/password
)

service="$1"

# Check if argument is provided
if [[ -z "$1" ]]; then
  echo "Usage: $0 <service>"
  echo "Allowed services: ${allowed_services[*]}"
  exit 1
fi

# Check if FEATURES is provided
if [[ -z "$FEATURES" ]]; then
  echo "Empty FEATURES env" 
  exit 1
fi

function deploy_helm(){
  helm_args=("$@")
  echo "⏳ Deploying '$1' with helm."
  helm upgrade --install $1 openstack-helm/$1 \
      --timeout=600s \
      --namespace=openstack \
      $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c $1 ${FEATURES} ${helm_args[@]} $values_dir/$1-conf 2>/dev/null)
  return $?
}

function update_swift(){
  echo "⏳ Deploying '$1' with kubectl."  
  kubectl apply -f swift/rook-rgw.yaml
  return $?
}

# Check if service is in allowed list
if [[ " ${allowed_services[*]} " =~ " ${service} " ]]; then
  echo "✅ Service '$service' is valid."

  if [[ "$service" == "swift" ]]; then
      update_swift $service
      if [[ $? != 0 ]]; then
        exit $?
      fi

      continue
      
  fi

  echo "$service" | grep -Eq '^(magnum|openvswitch|ovn)$'
  if [[ $? -eq 0 ]]; then
    default_helm_args+=(ubuntu_jammy)
  fi

  deploy_helm $service "${default_helm_args[@]}"
  if [[ $? != 0 ]]; then
    exit $?
  fi

else
  echo "❌ Invalid service: '$service'"
  echo "Allowed services: ${allowed_services[*]}"
  exit 1
fi
