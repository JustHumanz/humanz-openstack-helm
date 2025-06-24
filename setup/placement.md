# Setup helm manifest

```bash
mkdir -p placement/values_overrides/
tee placement/values_overrides/password.yaml  <<EOF
endpoints:
  identity:
    auth:
      admin:
        region_name: RegionOne
        password: "$osh_os_admin_password"
      placement:
        region_name: RegionOne
        password: "$osh_os_placement_user_password"
  oslo_db:
    auth:
      admin:
        password: "$osh_mariadb_password"
      placement:
        password: "$osh_mariadb_placement_password"
      nova_api:
        password: "$osh_mariadb_nova_password"        
  oslo_messaging:
    auth:
      admin:
        password: "$osh_rabbitmq_password"
      placement:
        password: "$osh_rabbitmq_placement_password"
EOF

tee placement/values_overrides/placement-conf.yaml  <<EOF
manifests:
  ingress: false
  service_ingress: false
EOF

helm upgrade --install placement openstack-helm/placement \
    --timeout=600s \
    --namespace=openstack \
    --set volume.class_name=ceph-rbd \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c placement ${FEATURES} values_overrides/password values_overrides/placement-conf)
```