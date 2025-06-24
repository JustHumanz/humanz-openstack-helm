# Setup helm manifest

```bash
mkdir -p libvirt/values_overrides/
tee libvirt/values_overrides/libvirt-conf.yaml  <<EOF
---
dependencies:
  dynamic:
    targeted:
      openvswitch:
        libvirt:
          pod: []

conf:
  ceph:
    enabled: true
EOF

```

# Install libvirt
```bash
helm upgrade --install libvirt openstack-helm/libvirt \
    --namespace=openstack \
    --set conf.ceph.enabled=true \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c libvirt ${FEATURES} values_overrides/libvirt-conf)
```    