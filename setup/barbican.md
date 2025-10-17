
# Setup helm manifest

```bash
mkdir -p barbican/values_overrides/

tee barbican/values_overrides/domain.yaml  <<EOF
endpoints:
  image:
    host_fqdn_override:
      public:
        host: "barbican.ctl1-humanz.cloud"      
EOF

tee barbican/values_overrides/password.yaml  <<EOF
endpoints:
  identity:
    auth:
      admin:
        region_name: RegionOne
        password: "$osh_os_admin_password"
      barbican:
        region_name: RegionOne
        password: "$osh_os_barbican_user_password"
  oslo_db:
    auth:
      admin:
        password: "$osh_mariadb_password"
      barbican:
        password: "$osh_mariadb_barbican_password"
  oslo_messaging:
    auth:
      admin:
        password: "$osh_rabbitmq_password"
      barbican:
        password: "$osh_rabbitmq_barbican_password"

conf:
  barbican:
    simple_crypto_plugin:
      kek: "$osh_os_barbican_kek"
  simple_crypto_kek_rewrap:
    old_kek: "$osh_os_barbican_kek"
EOF

tee barbican/values_overrides/barbican-conf.yaml  <<EOF
pod:
  replicas:
    api: 1

endpoints:
  key_manager:
    scheme:
      public: https
    port:
      api:
        public: 443  

manifests:
  ingress_api: false
  service_ingress_api: false
EOF
```

# Install glance helm & watch

```bash
helm upgrade --install barbican openstack-helm/barbican \
    --timeout=600s \
    --namespace=openstack \
    --set volume.class_name=ceph-rbd \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c barbican ${FEATURES} values_overrides/domain values_overrides/password values_overrides/barbican-conf)

kubectl -n openstack get pods -l application=barbican -w

tee barbican/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.org/client-max-body-size: "999m"
  name: barbican
  namespace: openstack
spec:
  tls:
    - hosts:
        - "barbican.ctl1-humanz.cloud"
      secretName: humanz-cloud-tls
  ingressClassName: nginx
  rules:
  - host: barbican.ctl1-humanz.cloud
    http:
      paths:
      - backend:
          service:
            name: barbican-api
            port:
              name: b-api
        path: /
        pathType: Prefix
EOF
kubectl apply -f barbican/ingress.yaml
```