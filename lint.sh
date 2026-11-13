#!/bin/bash

# service list names
os_services=(
  barbican
  cinder
  glance
  heat
  horizon
  keystone
  libvirt
  magnum
  neutron
  nova
  octavia
  openvswitch
  ovn
  placement
)

OVERRIDES_DIR=$PWD

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

function lint_helm(){
  helm_args=("$@")
  echo "⏳ Lint '$1' with helm."
  helm lint openstack-helm/$1 \
      $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c $1 ${FEATURES} ${helm_args[@]} $values_dir/$1-conf 2>/dev/null) 1> /dev/null
  return $?
}

function render_helm(){
  helm_args=("$@")
  echo "🔄 Render '$1' with helm."
  helm template $1 openstack-helm/$1 \
      $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c $1 ${FEATURES} ${helm_args[@]} $values_dir/$1-conf 2>/dev/null) > /tmp/$1.yaml
  return $?
}

for service in ${os_services[@]};
  do
    echo "$service" | grep -Eq '^(ovn)$'
    if [[ $? -eq 0 ]]; then
      default_helm_args+=(ubuntu_jammy)
    fi

    # Lint the OpenStack chart
    lint_helm $service "${default_helm_args[@]}"
    if [[ $? != 0 ]]; then
      exit $?
    fi

    # Render the OpenStack chart
    render_helm $service "${default_helm_args[@]}"
    if [[ $? != 0 ]]; then
      exit $?
    fi    
done;