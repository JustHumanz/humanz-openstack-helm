
# Setup helm manifest

```
mkdir -p glance/values_overrides/

tee glance/values_overrides/domain.yaml  <<EOF
endpoints:
  image:
    host_fqdn_override:
      public:
        host: "glance.ctl1-humanz.cloud"      
EOF

tee glance/values_overrides/password.yaml  <<EOF
endpoints:
  identity:
    auth:
      admin:
        region_name: RegionOne
        password: "$osh_os_admin_password"
      glance:
        region_name: RegionOne
        password: "$osh_os_glance_user_password"
      test:
        region_name: RegionOne
  oslo_db:
    auth:
      admin:
        password: "$osh_mariadb_password"
      glance:
        password: "$osh_mariadb_glance_password"
  oslo_messaging:
    auth:
      admin:
        password: "$osh_rabbitmq_password"
      glance:
        password: "$osh_rabbitmq_glance_password"
EOF

tee glance/values_overrides/glance-conf.yaml  <<EOF
storage: rbd
conf:
  glance:
    rbd:
      rbd_store_chunk_size: 8
      rbd_store_replication: 1
      rbd_store_crush_rule: replicated_rule
endpoints:
  identity:
    hosts:
      default: keystone-api
      internal: keystone-api
    scheme:
      public: https
    port:
      api:
        default: 5000
        public: 443
  image:
    hosts:
      default: glance-api
    scheme:
      public: https
    port:
      api:
        default: 9292
        public: 443     
manifests:
  ingress_api: false
  service_ingress_api: false
EOF
```

# Install glance helm & watch

```
helm upgrade --install glance openstack-helm/glance \
    --timeout=600s \
    --namespace=openstack \
    --set volume.class_name=ceph-rbd \
    --set volume.size=10Gi \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c glance ${FEATURES} values_overrides/domain values_overrides/password values_overrides/glance-conf)

kubectl -n openstack get pods -l application=glance -w

tee glance/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.org/client-max-body-size: "999m"
  name: glance
  namespace: openstack
spec:
  tls:
    - hosts:
        - "glance.ctl1-humanz.cloud"
      secretName: humanz-cloud-tls
  ingressClassName: nginx
  rules:
  - host: glance.ctl1-humanz.cloud
    http:
      paths:
      - backend:
          service:
            name: glance-api
            port:
              name: g-api
        path: /
        pathType: Prefix
EOF
kubectl apply -f glance/ingress.yaml
```