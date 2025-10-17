# Setup helm manifest

```bash
mkdir -p magnum/values_overrides/

tee magnum/values_overrides/domain.yaml  <<EOF
endpoints:
  container_infra:
    host_fqdn_override:
      public:
        host: "magnum.ctl1-humanz.cloud"
EOF

tee magnum/values_overrides/password.yaml  <<EOF
endpoints:
  identity:
    auth:
      admin:
        region_name: RegionOne
        password: "$osh_os_admin_password"
      magnum:
        region_name: RegionOne
        password: "$osh_os_magnum_user_password"
      magnum_stack_user:
        region_name: RegionOne
        password: "$osh_os_magnum_stack_user_password"
  oslo_db:
    auth:
      admin:
        password: "$osh_mariadb_password"
      keystone:
        password: "$osh_mariadb_magnum_password"
  oslo_messaging:
    auth:
      admin:
        password: "$osh_rabbitmq_password"
      magnum:
        password: "$osh_rabbitmq_magnum_password"

conf:
  magnum:
    keystone_auth:
      password: "$osh_os_magnum_user_password"
EOF

tee magnum/values_overrides/magnum-conf.yaml  <<EOF
conf:
  magnum:
    DEFAULT:
      log_config_append: null
      debug: "True"
    api:
      workers: 1
    cluster_template:
      kubernetes_allowed_network_drivers: calico
      kubernetes_default_network_driver: calico
    capi_client:
      endpoint_type: internalURL
      insecure: "True"
    drivers:
      verify_ca: "False"
    barbican_client:
      endpoint_type: internalURL
      region_name: RegionOne
    cinder_client:
      endpoint_type: internalURL
      region_name: RegionOne
    glance_client:
      endpoint_type: internalURL
      region_name: RegionOne
    heat_client:
      endpoint_type: internalURL
      region_name: RegionOne
    manila_client:
      endpoint_type: internalURL
      region_name: RegionOne
    magnum_client:
        region_name: RegionOne
    neutron_client:
      endpoint_type: internalURL
      region_name: RegionOne
    nova_client:
      api_version: 2.15
      endpoint_type: internalURL
      region_name: RegionOne
    octavia_client:
      endpoint_type: internalURL
      region_name: RegionOne
    keystone_auth:
      auth_url: http://keystone-api.openstack.svc.cluster.local:5000/v3
      user_domain_name: service
      username: "magnum"
      insecure: "True"
    keystone_authtoken:
      interface: internalURL
      insecure: "True"
      region_name: RegionOne
      www_authenticate_uri: http://keystone-api.openstack.svc.cluster.local:5000/v3
    trust:
      trustee_keystone_interface: public
      trustee_keystone_region_name: RegionOne

endpoints:
  container_infra:
    scheme:
      public: https  
    port:
      api:
        public: 443

pod:
  replicas:
    api: 1
    conductor: 1

manifests:
  ingress_api: false
  service_ingress_api: false
EOF
```
Build magnum image
```bash
export PRIVATE_REGISTRY={YOUR_REGISTRY}
docker build magnum/ -t $PRIVATE_REGISTRY/airshipit/magnum:2025.1-ubuntu_noble
docker push $PRIVATE_REGISTRY/airshipit/magnum:2025.1-ubuntu_noble
```

Define Image 
```bash
tee magnum/ubuntu_jammy.yaml  <<EOF
images:
  tags:
    bootstrap: quay.io/airshipit/heat:2025.1-ubuntu_noble
    db_init: quay.io/airshipit/heat:2025.1-ubuntu_noble
    magnum_db_sync: $PRIVATE_REGISTRY/airshipit/magnum:2025.1-ubuntu_noble
    db_drop: quay.io/airshipit/heat:2025.1-ubuntu_noble
    rabbit_init: docker.io/rabbitmq:3.13-management
    ks_user: quay.io/airshipit/heat:2025.1-ubuntu_noble
    ks_service: quay.io/airshipit/heat:2025.1-ubuntu_noble
    ks_endpoints: quay.io/airshipit/heat:2025.1-ubuntu_noble
    magnum_api: $PRIVATE_REGISTRY/airshipit/magnum:2025.1-ubuntu_noble
    magnum_conductor: $PRIVATE_REGISTRY/airshipit/magnum:2025.1-ubuntu_noble
    dep_check: quay.io/airshipit/kubernetes-entrypoint:latest-ubuntu_focal
    image_repo_sync: docker.io/docker:17.07.0
EOF
```
Create ClusterRole 
```
tee magnum/ClusterRole.yaml  <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: magnum-capi
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: magnum-conductor
    namespace: openstack
EOF

kubectl apply -f magnum/ClusterRole.yaml
```

# Install magnum & watch

```bash
helm upgrade --install magnum openstack-helm/magnum \
    --timeout=600s \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c magnum ${FEATURES} ubuntu_jammy values_overrides/domain values_overrides/password values_overrides/magnum-conf)

kubectl -n openstack get pods -l application=magnum -w

tee magnum/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  name: magnum
  namespace: openstack
spec:
  tls:
    - hosts:
        - "magnum.ctl1-humanz.cloud"
      secretName: humanz-cloud-tls
  ingressClassName: nginx
  rules:
  - host: magnum.ctl1-humanz.cloud
    http:
      paths:
      - backend:
          service:
            name: magnum-api
            port:
              name: m-api
        path: /
        pathType: Prefix
EOF
kubectl apply -f magnum/ingress.yaml
```
## Create Image&Template
```
wget https://static.atmosphere.dev/artifacts/magnum-cluster-api/ubuntu-jammy-kubernetes-1-31-1-1728920853.qcow2 -O ubuntu-jammy-kubernetes-v1-31-1.qcow2

openstack image create ubuntu-jammy-kube-v1-31-1 \
  --file ubuntu-jammy-kubernetes-v1-31-1.qcow2  \
  --disk-format qcow2 \
  --container-format bare \
  --public \
  --progress

openstack image set ubuntu-jammy-kube-v1-31-1 --os-distro ubuntu --os-version 22.04 --property os_distro=ubuntu 
openstack coe cluster template create kube-v1-31-1 --coe kubernetes \
  --label octavia_provider=ovn --image $(openstack image show ubuntu-jammy-kube-v1-31-1 -c id -f value) \
  --external-network ext-net --master-flavor m1.medium  --flavor m1.medium --public \
  --dns-nameserver 172.16.18.1 --label kube_tag=v1.31.1

openstack coe cluster create --cluster-template kube-v1.32.1 --master-count 1 --node-count 1 --keypair ctl1 test-cluster

```