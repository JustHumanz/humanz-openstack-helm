# Setup helm manifest

```
mkdir -p cinder/values_overrides/

tee cinder/values_overrides/domain.yaml  <<EOF
endpoints:
  image:
    host_fqdn_override:
      public:
        host: "cinder.ctl1-humanz.cloud"
EOF

tee cinder/values_overrides/password.yaml  <<EOF
endpoints:
  identity:
    auth:
      admin:
        region_name: RegionOne
        password: "$osh_os_admin_password"
      cinder:
        region_name: RegionOne
        password: "$osh_os_cinder_user_password"
      nova:
        region_name: RegionOne
        password: "$osh_os_cinder_nova_user_password"
      swift:
        region_name: RegionOne
        password: "$osh_os_cinder_swift_user_password"
        project_domain_name: service
      service:
        region_name: RegionOne
        password: "$osh_os_cinder_service_user_password"
      test:
        region_name: RegionOne
  oslo_db:
    auth:
      admin:
        password: "$osh_mariadb_password"
      cinder:
        password: "$osh_mariadb_cinder_password"
  oslo_messaging:
    auth:
      admin:
        password: "$osh_rabbitmq_password"
      cinder:
        password: "$osh_rabbitmq_cinder_password"
EOF

tee cinder/values_overrides/cinder-conf.yaml  <<EOF
pod:
  security_context:
    cinder_volume:
      container:
        cinder_volume:
          privileged: true
conf:
  ceph:
    pools:
      backup:
        replication: 1
      cinder.volumes:
        replication: 1
  cinder:
    DEFAULT:
      os_region_name: RegionOne
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
      internal: glance-api
    scheme:
      public: https
    port:
      api:
        default: 9292
        public: 80
  volumev3:
    hosts:
      default: cinder-api
    scheme:
      public: 'https'
    port:
      api:
        default: 8776
        public: 443
manifests:
  ingress_api: false
  service_ingress_api: false
EOF
```
# Install cinder & watch
```
helm upgrade --install cinder openstack-helm/cinder \
    --timeout=600s \
    --namespace=openstack \
    --set volume.class_name=ceph-rbd \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c cinder ${FEATURES} values_overrides/domain values_overrides/password values_overrides/cinder-conf)

kubectl -n openstack get pods -l application=cinder -w

tee cinder/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  name: cinder
  namespace: openstack
spec:
  tls:
    - hosts:
        - "cinder.ctl1-humanz.cloud"
      secretName: humanz-cloud-tls
  ingressClassName: nginx
  rules:
  - host: cinder.ctl1-humanz.cloud
    http:
      paths:
      - backend:
          service:
            name: cinder-api
            port:
              name: c-api
        path: /
        pathType: Prefix
EOF
kubectl apply -f cinder/ingress.yaml
```
