# Setup helm manifest

```
mkdir -p horizon/values_overrides/
tee horizon/values_overrides/domain.yaml  <<EOF
endpoints:
  dashboard:
    host_fqdn_override:
      public:
        host: "horizon.ctl1-humanz.cloud"  
EOF

tee horizon/values_overrides/password.yaml  <<EOF
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
      horizon:
        password: "$osh_mariadb_horizon_password"
  oslo_messaging:
    auth:
      admin:
        password: "$osh_rabbitmq_password"
      horizon:
        password: "$osh_rabbitmq_horizon_password"
EOF

tee horizon/values_overrides/horizon-conf.yaml  <<EOF
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
  dashboard:
    hosts:
      default: horizon-int
    scheme:
      public: https
    port:
      api:
        default: 80
        public: 443
manifests:
  ingress_api: false
  service_ingress: false
EOF
```
# Install Horizon & watch

```
helm upgrade --install horizon openstack-helm/horizon \
    --timeout=600s \
    --namespace=openstack \
    --set volume.class_name=ceph-rbd \
    --set volume.size=10Gi \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c horizon ${FEATURES} values_overrides/domain values_overrides/password values_overrides/horizon-conf)

kubectl -n openstack get pods -l application=horizon -w

tee horizon/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  name: horizon
  namespace: openstack
spec:
  tls:
    - hosts:
        - "horizon.ctl1-humanz.cloud"
      secretName: humanz-cloud-tls
  ingressClassName: nginx
  rules:
  - host: horizon.ctl1-humanz.cloud
    http:
      paths:
      - backend:
          service:
            name: horizon-api
            port:
              name: web
        path: /
        pathType: Prefix
EOF
kubectl apply -f horizon/ingress.yaml
```