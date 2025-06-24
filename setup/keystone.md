# Setup helm manifest

```
mkdir -p keystone/values_overrides
tee keystone/values_overrides/domain.yaml  <<EOF
endpoints:
  identity:
    host_fqdn_override:
      public:
        host: "keystone.ctl1-humanz.cloud"
EOF

tee keystone/values_overrides/password.yaml  <<EOF
endpoints:
  identity:
    auth:
      admin:
        region_name: RegionOne
        password: "$osh_os_admin_password"
  oslo_db:
    auth:
      admin:
        password: "$osh_mariadb_password"
      keystone:
        password: "$osh_mariadb_keystone_password"
  oslo_messaging:
    auth:
      admin:
        password: "$osh_rabbitmq_password"
      keystone:
        password: "$osh_rabbitmq_keystone_password"
EOF

tee keystone/values_overrides/keystone-conf.yaml  <<EOF
endpoints:
  identity:
    scheme:
      public: https
    port:
      api:
        default: 5000
        public: 443
manifests:
  ingress_api: false
  service_ingress_api: false
EOF
```

# Install keystone & watch
```
helm upgrade --install keystone openstack-helm/keystone \
    --timeout=600s \
    --namespace=openstack \
    --set volume.class_name=ceph-rbd \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c keystone ${FEATURES} values_overrides/domain values_overrides/password values_overrides/keystone-conf)

kubectl -n openstack get pods -l application=keystone -w

tee keystone/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  name: keystone
  namespace: openstack
spec:
  tls:
    - hosts:
        - "keystone.ctl1-humanz.cloud"
      secretName: humanz-cloud-tls
  ingressClassName: nginx
  rules:
  - host: keystone.ctl1-humanz.cloud
    http:
      paths:
      - backend:
          service:
            name: keystone-api
            port:
              name: ks-pub
        path: /
        pathType: Prefix
EOF
kubectl apply -f keystone/ingress.yaml
```