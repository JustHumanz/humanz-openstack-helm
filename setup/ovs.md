# Setup openvswitch

```
helm upgrade --install openvswitch openstack-helm/openvswitch \
    --namespace=openstack \
    --set conf.openvswitch_db_server.ptcp_port=6640 \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c openvswitch ubuntu_jammy)
```    