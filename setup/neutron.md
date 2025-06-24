# Setup helm manifest

```bash
mkdir -p neutron/values_overrides
tee neutron/values_overrides/domain.yaml  <<EOF
endpoints:
  network:
    host_fqdn_override:
      public:
        host: "neutron.ctl1-humanz.cloud"
EOF


tee neutron/values_overrides/password.yaml  <<EOF
endpoints:
  identity:
    auth:
      admin:
        region_name: RegionOne
        password: "$osh_os_admin_password"
      neutron:
        region_name: RegionOne
        password: "$osh_os_cinder_user_password"
      nova:
        region_name: RegionOne
        password: "$osh_os_nova_user_password"
      placement:
        region_name: RegionOne
        password: "$osh_os_neutron_placement_user_password"
      test:
        region_name: RegionOne
  oslo_db:
    auth:
      admin:
        password: "$osh_mariadb_password"
      neutron:
        password: "$osh_mariadb_neutron_password"
  oslo_messaging:
    auth:
      admin:
        password: "$osh_rabbitmq_password"
      neutron:
        password: "$osh_rabbitmq_neutron_password"
EOF


tee neutron/values_overrides/neutron-conf.yaml  <<EOF
network:
  backend:
    - openvswitch
    - ovn

conf:
  neutron:
    DEFAULT:
      router_distributed: True
      service_plugins: ovn-router
      l3_ha_network_type: geneve
  plugins:
    ml2_conf:
      ml2:
        extension_drivers: port_security
        type_drivers: flat,vxlan,geneve
        tenant_network_types: geneve
      ovn:
        ovn_l3_scheduler: leastloaded
        dns_servers: 8.8.8.8,1.1.1.1
        neutron_sync_mode: repair

endpoints:
  network:
    hosts:
      default: neutron-server
      internal: neutron-server
    scheme:
      public: 'https'
    port:
      api:
        public: 443

manifests:
  daemonset_dhcp_agent: false
  daemonset_l3_agent: false
  daemonset_metadata_agent: false
  daemonset_ovs_agent: false
  deployment_rpc_server: false

  daemonset_ovn_metadata_agent: true  
  ingress_server: false
  service_ingress_server: false          
EOF
```

# Install neutron & watch

```bash
helm upgrade --install neutron openstack-helm/neutron \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c neutron ${FEATURES} values_overrides/domain values_overrides/password values_overrides/neutron-conf)

kubectl -n openstack get pods -l application=neutron -w

tee neutron/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  name: neutron
  namespace: openstack
spec:
  tls:
    - hosts:
        - "neutron.ctl1-humanz.cloud"
      secretName: humanz-cloud-tls
  ingressClassName: nginx
  rules:
  - host: neutron.ctl1-humanz.cloud
    http:
      paths:
      - backend:
          service:
            name: neutron-server
            port:
              name: q-api
        path: /
        pathType: Prefix
EOF
kubectl apply -f neutron/ingress.yaml
```