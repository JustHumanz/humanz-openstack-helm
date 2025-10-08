# Create mtls for octavia services
```bash
tee cert-manager/octavia-cert.yaml <<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: "octavia-server-ca"
  namespace: openstack
spec:
  isCA: true
  commonName: "octavia-server"
  secretName: "octavia-server-ca"
  duration: 87600h0m0s
  renewBefore: 720h0m0s
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: humanz-cloud-selfsigned-issuer
    kind: Issuer
    group: cert-manager.io
---    
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: "octavia-server"
  namespace: openstack
spec:
  ca:
    secretName: "octavia-server-ca"

# Certificates Client for Octavia
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: "octavia-client-ca"
  namespace: openstack
spec:
  isCA: true
  commonName: "octavia-client"
  secretName: "octavia-client-ca"
  duration: 87600h0m0s
  renewBefore: 720h0m0s
  privateKey:
    algorithm: ECDSA
    size: 256  
  issuerRef:
    name: humanz-cloud-selfsigned-issuer
    kind: Issuer
    group: cert-manager.io
---    
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: "octavia-client"
  namespace: openstack
spec:
  ca:
    secretName: "octavia-client-ca"
    
# Create certificate for Octavia clients
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: octavia-client-certs
  namespace: openstack
spec:
  commonName: "octavia-client"
  secretName: octavia-client-certs
  additionalOutputFormats:
    - type: CombinedPEM
  duration: 87600h0m0s
  renewBefore: 720h0m0s
  privateKey:
    algorithm: ECDSA
    size: 256  
  issuerRef:
    name: octavia-client
    kind: Issuer
    group: cert-manager.io
EOF
kubectl apply -f cert-manager/octavia-cert.yaml
```
# Create octavia network,sec group,ssh-key,image
```bash
wget https://tarballs.opendev.org/openstack/octavia/test-images/test-only-amphora-x64-haproxy-ubuntu-jammy.qcow2
openstack image create amphora-x64-haproxy-ubuntu-jammy --public --container-format=bare --disk-format qcow2 --min-disk 2 --file test-only-amphora-x64-haproxy-ubuntu-jammy.qcow2 --progress
openstack image set --tag octavia-amphora-image amphora-x64-haproxy-ubuntu-jammy
IMAGE_OWNER_ID=$(openstack image show 11913b6a-2709-435f-a03d-bae94668f302 -c owner -f value)

openstack network create lb-mgmt-net

# Create subnet
openstack subnet create \
  --network lb-mgmt-net \
  --subnet-range 10.10.10.0/23 \
  lb-mgmt-subnet

openstack security group create octavia-sec-group \
  --description "Security group for Octavia amphora instances"

# Allow TCP 5555 (Octavia health manager)
openstack security group rule create --protocol tcp --dst-port 5555 octavia-sec-group
# Allow UDP 5555 (keepalived VRRP sync if used)
openstack security group rule create --protocol udp --dst-port 5555 octavia-sec-group
# HTTP
openstack security group rule create --protocol tcp --dst-port 80 octavia-sec-group
# HTTPS
openstack security group rule create --protocol tcp --dst-port 443 octavia-sec-group
# Octavia HTTPs
openstack security group rule create --protocol tcp --dst-port 9443 octavia-sec-group
# Allow all egress so the amphora can reach backend members
openstack security group rule create --egress --protocol any octavia-sec-group
openstack security group rule create --protocol tcp --dst-port 22 octavia-sec-group

openstack keypair create octavia-key > octavia-key.pem

openstack port create --network lb-mgmt-net octavia-manager-port-ctl1-humanz
openstack port set --host $HOSTNAME octavia-manager-port-ctl1-humanz


openstack port create --network lb-mgmt-net octavia-health-manager-port-ctl1-humanz
openstack port set --host $HOSTNAME octavia-health-manager-port-ctl1-humanz

OCTAVIA_NETWORK=$(openstack network show lb-mgmt-net -f value -c ID)
OCTAVIA_SEC_GROUP=$(openstack security group show octavia-sec-group -c id -f value)
OCTAVIA_FLAVOR=$(openstack flavor show m1.small -c id -f value)
```

```bash
mkdir -p octavia/values_overrides/

tee nova/values_overrides/domain.yaml  <<EOF
endpoints:
  load_balancer:
    host_fqdn_override:
      public:
        host: "load-balancer.ctl1-humanz.cloud"
EOF

tee nova/values_overrides/password.yaml  <<EOF
endpoints:
  identity:
    auth:
      admin:
        region_name: RegionOne
        password: "$osh_os_admin_password"
      octavia:
        region_name: RegionOne
        password: "$osh_os_octavia_user_password"
      test:
        region_name: RegionOne
  oslo_db:
    auth:
      admin:
        password: "$osh_mariadb_password"
      octavia:
        password: "$osh_mariadb_octavia_password"
  oslo_db_persistence:
    auth:
      admin:
        password: "$osh_mariadb_password"
      octavia:
        password: "$osh_mariadb_octavia_password"   
  oslo_messaging:
    auth:
      admin:
        password: "$osh_rabbitmq_password"
      octavia:
        password: "$osh_rabbitmq_octavia_password"
EOF

tee horizon/values_overrides/octavia-conf.yaml  <<EOF
endpoints:
  load_balancer:
    name: octavia
    hosts:
      default: octavia-api
    scheme:
      public: https
    port:
      api:
        public: 443

pod:
  probes:
    api:
      octavia-api:
        liveness:
          enabled: false
        readiness:
          enabled: false
  replicas:
    api: 1
    worker: 1
    housekeeping: 1
  mounts:
    octavia_api:
      octavia_api:
        volumeMounts:
          - name: octavia-server-ca
            mountPath: /etc/octavia/certs/server
          - name: octavia-client-certs
            mountPath: /etc/octavia/certs/client
        volumes:
          - name: octavia-server-ca
            secret:
              secretName: octavia-server-ca
          - name: octavia-client-certs
            secret:
              secretName: octavia-client-certs
    octavia_worker:
      octavia_worker:
        volumeMounts:
          - name: octavia-server-ca
            mountPath: /etc/octavia/certs/server
          - name: octavia-client-certs
            mountPath: /etc/octavia/certs/client
        volumes:
          - name: octavia-server-ca
            secret:
              secretName: octavia-server-ca
          - name: octavia-client-certs
            secret:
              secretName: octavia-client-certs
    octavia_housekeeping:
      octavia_housekeeping:
        volumeMounts:
          - name: octavia-server-ca
            mountPath: /etc/octavia/certs/server
          - name: octavia-client-certs
            mountPath: /etc/octavia/certs/client
        volumes:
          - name: octavia-server-ca
            secret:
              secretName: octavia-server-ca
          - name: octavia-client-certs
            secret:
              secretName: octavia-client-certs
    octavia_health_manager:
      octavia_health_manager:
        volumeMounts:
          - name: octavia-server-ca
            mountPath: /etc/octavia/certs/server
          - name: octavia-client-certs
            mountPath: /etc/octavia/certs/client
        volumes:
          - name: octavia-server-ca
            secret:
              secretName: octavia-server-ca
          - name: octavia-client-certs
            secret:
              secretName: octavia-client-certs

security_context:
    octavia_worker:
      container:
        octavia_worker:
          capabilities:
            add:
              - NET_ADMIN
              - NET_RAW
    octavia_health_manager:
      container:
        octavia_health_manager:
          capabilities:
            add:
              - NET_ADMIN
              - NET_RAW

conf:
  octavia_api_uwsgi:
    uwsgi:
      wsgi-file: /var/lib/openstack/bin/octavia-wsgi
  octavia:
    DEFAULT:
      debug: "True"
    api_settings:
      default_provider_driver: amphorav2
      enabled_provider_drivers: amphorav2:'The v2 amphora driver.',amphora:'The Octavia Amphora driver.',octavia:'Deprecated name of Amphora driver.' 
      healthcheck_enabled: false
    certificates:
      ca_certificate: /etc/octavia/certs/server/ca.crt
      ca_private_key: /etc/octavia/certs/server/tls.key
      ca_private_key_passphrase: null
      endpoint_type: internalURL
    haproxy_amphora:
      client_cert: /etc/octavia/certs/client/tls-combined.pem
      server_ca: /etc/octavia/certs/server/ca.crt
    controller_worker:
      amp_image_owner_id: $IMAGE_OWNER_ID
      amp_secgroup_list: $OCTAVIA_SEC_GROUP
      amp_flavor_id: $OCTAVIA_FLAVOR
      amp_boot_network_list: $OCTAVIA_NETWORK
      amp_ssh_key_name: octavia-key
      amp_image_tag: octavia-amphora-image
      network_driver: allowed_address_pairs_driver
      compute_driver: compute_nova_driver
      amphora_driver: amphora_haproxy_rest_driver
      client_ca: /etc/octavia/certs/client/ca.crt
      workers: 4
    task_flow:
      jobboard_enabled: false
    health_manager:
      controller_ip_port_list: "192.168.18.100:5555"
    cinder:
      endpoint_type: internalURL
    glance:
      endpoint_type: internalURL
    neutron:
      endpoint_type: internalURL
    nova:
      endpoint_type: internalURL

manifests:
  ingress_api: false
  service_ingress_api: false
EOF
```

# Install Octavia
```
helm upgrade --install octavia openstack-helm/octavia \
    --timeout=600s \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c octavia ${FEATURES} values_overrides/domain values_overrides/password values_overrides/octavia-conf)

```