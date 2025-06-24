# Setup helm manifest

```bash
mkdir -p /values_overrides/
tee nova/values_overrides/domain.yaml  <<EOF
endpoints:
  compute:
    host_fqdn_override:
      public:
        host: "nova.ctl1-humanz.cloud"
  compute_novnc_proxy:
    host_fqdn_override:
      public:
        host: "vnc.ctl1-humanz.cloud"
EOF

tee nova/values_overrides/password.yaml  <<EOF
endpoints:
  identity:
    auth:
      admin:
        region_name: RegionOne
        password: "$osh_os_admin_password"
      nova:
        password: "$osh_os_nova_user_password"
      service:
        password: "$osh_os_nova_service_user_password"
      # NOTE(portdirect): the neutron user is not managed by the nova chart
      # these values should match those set in the neutron chart.
      neutron:
        region_name: RegionOne
        password: "$osh_os_neutron_user_password"
      placement:
        region_name: RegionOne
        password: "$osh_os_nova_placement_user_password"
      cinder:
        region_name: RegionOne
        password: "$osh_os_nova_cinder_user_password"
      test:
        region_name: RegionOne
  oslo_db:
    auth:
      admin:
        password: "$osh_mariadb_password"
      nova:
        password: "$osh_mariadb_nova_password"
  oslo_db_api:
    auth:
      admin:
        password: "$osh_mariadb_password"
      nova:
        password: "$osh_mariadb_nova_password"
  oslo_db_cell0:
    auth:
      admin:
        password: "$osh_mariadb_password"
      nova:
        password: "$osh_mariadb_nova_password"      
  oslo_messaging:
    auth:
      admin:
        password: "$osh_rabbitmq_password"
      nova:
        password: "$osh_rabbitmq_nova_password"
EOF

tee nova/values_overrides/nova-conf.yaml  <<EOF
pod:
  probes:
    rpc_timeout: 60
    rpc_retries: 2
    compute:
      default:
        liveness:
          enabled: False
        readiness:
          enabled: False
        startup:
          enabled: False
conf:
  nova:
    DEFAULT:
      vif_plugging_is_fatal: true
      vif_plugging_timeout: 300
    vnc:
      auth_schemes: none
dependencies:
  dynamic:
    targeted:
      openvswitch:
        compute:
          pod: []
          
endpoints:
  oslo_messaging:
    statefulset:
      replicas: 1
  identity:
    hosts:
      default: keystone-api
      internal: keystone-api
  image:
    hosts:
      default: glance-api
      internal: glance-api
  compute:
    hosts:
      default: nova-api
    scheme:
      public: 'https'
    port:
      api:
        public: 443
      novncproxy:
        default: 6080
  compute_metadata:
    hosts:
      default: nova-metadata
    port:
      metadata:
        public: 8775        
  compute_novnc_proxy:
    scheme:
      public: 'https'
    port:
      novnc_proxy:
        public: 443
manifests:
  deployment_consoleauth: false
  deployment_placement: false
  ingress_metadata: false
  ingress_novncproxy: false
  ingress_osapi: false
  ingress_placement: false
  ingress_spiceproxy: false
  service_ingress_metadata: false
  service_ingress_novncproxy: false
  service_ingress_osapi: false
  service_ingress_placement: false
  service_placement: false
  service_ingress_spiceproxy: false  
EOF
```

# Install nova & watch
```bash
helm upgrade --install nova openstack-helm/nova \
    --timeout=600s \
    --namespace=openstack \
    --set bootstrap.wait_for_computes.enabled=true \
    --set conf.ceph.enabled=true \
    --set volume.class_name=ceph-rbd \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c nova ${FEATURES} values_overrides/domain values_overrides/password values_overrides/nova-conf)

tee nova/ingress-api.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  name: nova
  namespace: openstack
spec:
  tls:
    - hosts:
        - "nova.ctl1-humanz.cloud"
      secretName: humanz-cloud-tls
  ingressClassName: nginx
  rules:
  - host: nova.ctl1-humanz.cloud
    http:
      paths:
      - backend:
          service:
            name: nova-api
            port:
              name: n-api
        path: /
        pathType: Prefix     
EOF
kubectl apply -f nova/ingress-api.yaml


tee nova/ingress-vnc.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  name: nova-vnc
  namespace: openstack
spec:
  tls:
    - hosts:
        - "vnc.ctl1-humanz.cloud"
      secretName: humanz-cloud-tls
  ingressClassName: nginx
  rules:
  - host: vnc.ctl1-humanz.cloud
    http:
      paths:
      - backend:
          service:
            name: nova-novncproxy
            port:
              name: n-novnc
        path: /
        pathType: Prefix        
EOF
kubectl apply -f nova/ingress-vnc.yaml
```