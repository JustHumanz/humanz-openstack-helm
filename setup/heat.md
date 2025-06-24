# Setup helm manifest

```bash
mkdir -p heat/values_overrides/
tee heat/values_overrides/domain.yaml  <<EOF
endpoints:
  cloudformation:
    host_fqdn_override:
      public:
        host: "cloudformation.ctl1-humanz.cloud"
  orchestration:
    host_fqdn_override:
      public:
        host: "heat.ctl1-humanz.cloud"
  cloudwatch:
    host_fqdn_override:
      public:
        host: "cloudwatch.ctl1-humanz.cloud"
EOF

tee heat/values_overrides/password.yaml  <<EOF
endpoints:
  identity:
    auth:
      admin:
        region_name: RegionOne
        password: "$osh_os_admin_password"
      heat:
        region_name: RegionOne
        password: "$osh_os_heat_user_password"
      heat_trustee:
        region_name: RegionOne
        password: "$osh_os_heat_trustee_password"
      heat_stack_user:
        region_name: RegionOne
        password: "$osh_os_heat_stack_user_password"
      test:
        region_name: RegionOne
  oslo_db:
    auth:
      admin:
        password: "$osh_mariadb_password"
      heat:
        password: "$osh_mariadb_heat_password" 
  oslo_messaging:
    auth:
      admin:
        password: "$osh_rabbitmq_password"
      heat:
        password: "$osh_rabbitmq_heat_password" 
EOF

tee heat/values_overrides/heat-conf.yaml  <<EOF
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
  orchestration:
    hosts:
      default: heat-api
    scheme:
      public: 'https'
    port:
      api:
        default: 8004
        public: 443
  cloudformation:
    hosts:
      default: heat-cfn
    scheme:
      public: 'https'
    port:
      api:
        default: 8000      
        public: 443
  # Cloudwatch does not get an entry in the keystone service catalog
  cloudwatch:
    hosts:
      default: heat-cloudwatch
    scheme:
      public: 'https'
    port:
      api:
        default: 8003
        public: 443      
manifests:
  ingress_api: false
  ingress_cfn: false
  service_ingress_api: false
  service_ingress_cfn: false
EOF
```

# Install heat & watch
```bash
helm upgrade --install heat openstack-helm/heat \
    --timeout=600s \
    --namespace=openstack \
    --set volume.class_name=ceph-rbd \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c heat ${FEATURES} values_overrides/domain values_overrides/password values_overrides/heat-conf)

kubectl -n openstack get pods -l application=heat -w

tee heat/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  name: heat
  namespace: openstack
spec:
  tls:
    - hosts:
        - "heat.ctl1-humanz.cloud"
        - "cloudformation.ctl1-humanz.cloud"
      secretName: humanz-cloud-tls
  ingressClassName: nginx
  rules:
  - host: heat.ctl1-humanz.cloud
    http:
      paths:
      - backend:
          service:
            name: heat-api
            port:
              name: h-api
        path: /
        pathType: Prefix
  - host: cloudformation.ctl1-humanz.cloud
    http:
      paths:
      - backend:
          service:
            name: heat-cfn
            port:
              name: h-cfn
        path: /
        pathType: Prefix
EOF
kubectl apply -f heat/ingress.yaml
```