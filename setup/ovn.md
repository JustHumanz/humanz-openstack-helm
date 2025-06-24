# Setup helm manifest

```
mkdir -p ovn/values_overrides/
tee ovn/values_overrides/ovn-conf.yaml  <<EOF
conf:
  ovn_cms_options: "enable-chassis-as-gw,availability-zones=nova"
  ovn_bridge_mappings: public:br-ex
  auto_bridge_add:
    br-ex: fip

volume:
  ovn_ovsdb_nb:
    class_name: ceph-rbd
  ovn_ovsdb_sb:
    class_name: ceph-rbd
EOF
```
# Install ovs
```
helm upgrade --install ovn openstack-helm/ovn \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c ovn ${FEATURES} ubuntu_jammy values_overrides/ovn-conf)
```