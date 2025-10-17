#!/bin/bash

# service list names
services=(
  swift
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
)

OVERRIDES_DIR=$pwd

values_dir=values_overrides

default_helm_args=(
  $values_dir/domain
  $values_dir/password
)

# Check if FEATURES is provided
if [[ -z "$FEATURES" ]]; then
  echo "Empty FEATURES env" 
  exit 1
fi

function test_helm(){
  helm_args=("$@")
  echo "⏳ Testing '$1' with helm."
  helm upgrade --install $1 openstack-helm/$1 \
      --timeout=600s \
      --namespace=openstack \
      $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c $1 ${FEATURES} ${helm_args[@]} $values_dir/$1-conf 2>/dev/null) --dry-run=client --debug 1>/dev/null
  return $?
}

function test_swift(){
  echo "⏳ Testing ''$1' with kubectl."  
  kubectl apply -f swift/rook-rgw.yaml --dry-run=server
  return $?
}

for service in ${services[@]};
  do
    if [[ "$service" == "swift" ]]; then
        test_swift $service
         if [[ $? != 0 ]]; then
            exit $?
         fi
         continue
    fi

    echo "$service" | grep -Eq '^(magnum|openvswitch|ovn)$'
    if [[ $? -eq 0 ]]; then
      default_helm_args+=(ubuntu_jammy)
    fi

    test_helm $service "${default_helm_args[@]}"
    if [[ $? != 0 ]]; then
      exit $?
    fi
    
done;