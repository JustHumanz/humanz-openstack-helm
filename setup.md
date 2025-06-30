## Setup ceph
```bash
mkdir -p /opt/cephadm;cd /opt/cephadm
curl --silent --remote-name --location https://github.com/ceph/ceph/raw/quincy/src/cephadm/cephadm
chmod +x cephadm
./cephadm add-repo --release reef
./cephadm install
cephadm install ceph-common
mkdir -p /etc/ceph
cephadm bootstrap --mon-ip 192.168.18.100
sudo apparmor_parser -R /etc/apparmor.d/MongoDB_Compass
```

### Create local disk
```bash
fallocate /var/lib/openstack-helm/osdX.img -l X0G
losetup /dev/loopX0 /var/lib/openstack-helm/osdX.img
ceph orch daemon add osd $HOSTNAME:/dev/loop10 raw
ceph config set global mon_allow_pool_size_one true
ceph config set global mon_allow_pool_delete true

ceph osd pool create kube replicated_rule 32 32
ceph osd pool application enable kube rbd
ceph osd pool set kube size 1 --yes-i-really-mean-it
```

### Create dummy interface
```bash
ip link add fip type dummy
ip add add 172.16.18.1/24 dev fip
ip link set fip up
```

### Create NS
```bash
kubectl create ns openstack
kubectl create ns ingress-nginx
```

### Import external ceph as rook 
```bash
curl -s https://raw.githubusercontent.com/rook/rook/release-1.17/deploy/examples/create-external-cluster-resources.py > create-external-cluster-resources.py
python3 create-external-cluster-resources.py --rbd-data-pool-name kube --namespace openstack --format bash
>export NAMESPACE=openstack
>export ROOK_EXTERNAL_FSID=XXXXXXXXX
>export ROOK_EXTERNAL_USERNAME=client.healthchecker
>export ROOK_EXTERNAL_CEPH_MON_DATA=pve1=XXXXXXXXX
>export ROOK_EXTERNAL_USER_SECRET=XXXXXXXXX==
>export CSI_RBD_NODE_SECRET=XXXXXXXXX==
>export CSI_RBD_NODE_SECRET_NAME=csi-rbd-node
>export CSI_RBD_PROVISIONER_SECRET=XXXXXXXXX==
>export CSI_RBD_PROVISIONER_SECRET_NAME=csi-rbd-provisioner
>export CSI_CEPHFS_NODE_SECRET=XXXXXXXXX
>export CSI_CEPHFS_PROVISIONER_SECRET=XXXXXXXXX
>export CSI_CEPHFS_NODE_SECRET_NAME=csi-cephfs-node
>export CSI_CEPHFS_PROVISIONER_SECRET_NAME=csi-cephfs-provisioner
>export MONITORING_ENDPOINT=10.22.0.12
>export MONITORING_ENDPOINT_PORT=9283
>export RBD_POOL_NAME=kube
>export RGW_POOL_PREFIX=default
curl -s https://raw.githubusercontent.com/rook/rook/release-1.17/deploy/examples/import-external-cluster.sh > import-external-cluster.sh
./import-external-cluster.sh

export operatorNamespace="rook-ceph"
export clusterNamespace="openstack"
curl -s https://raw.githubusercontent.com/rook/rook/release-1.17/deploy/charts/rook-ceph/values.yaml > values.yaml
curl -s https://raw.githubusercontent.com/rook/rook/release-1.17/deploy/charts/rook-ceph-cluster/values-external.yaml > values-external.yaml
helm install --create-namespace --namespace $operatorNamespace rook-ceph rook-release/rook-ceph -f values.yaml
helm install --create-namespace --namespace $clusterNamespace rook-ceph-cluster \
--set operatorNamespace=$operatorNamespace rook-release/rook-ceph-cluster -f values-external.yaml

echo $(ceph auth ls | grep admin -A 3 | grep key: | sed 's/key: //' | tr -d '[:space:]') | base64 #Save the output
printf client.admin | base64 #Save the output
kubectl --namespace openstack edit secret rook-ceph-mon
```yaml
apiVersion: v1
data:
  admin-secret: XXXX
  ceph-secret: OUTPUT FROM CEPH AUTH
  ceph-username: OUTPUT FROM PRINTF
  cluster-name: XXXX
  fsid: XXXX
  mon-secret: XXXX
```
### Import ceph conf

```bash
tee /tmp/ceph.conf <<EOF
[global]
cephx = true
cephx_cluster_require_signatures = true
cephx_require_signatures = false
cephx_service_require_signatures = false
fsid = 65ac0dac-4acf-11f0-9751-a3dd4eabfabf
mon_allow_pool_delete = true
mon_compact_on_trim = true
mon_initial_members = "192.168.18.100"
mon_host = [v2:192.168.18.100:3300/0,v1:192.168.18.100:6789/0]
public_network = 192.168.18.0/24
cluster_network = 192.168.18.0/24

[osd]
cluster_network = 192.168.18.0/24
ms_bind_port_max = 7100
ms_bind_port_min = 6800
osd_max_object_name_len = 256
osd_mkfs_options_xfs = -f -i size=2048
osd_mkfs_type = xfs
public_network = 192.168.18.0/24
EOF

kubectl create configmap ceph-etc -n openstack --from-file=/tmp/ceph.conf
echo $(ceph auth ls | grep admin -A 3 | grep key: | sed 's/key: //' | tr -d '[:space:]') > /tmp/key
kubectl create secret generic pvc-ceph-client-key -n openstack --from-file=/tmp/key
```

### Add openstack helm repo
```bash
helm repo add openstack-helm https://tarballs.opendev.org/openstack/openstack-helm
helm plugin install https://opendev.org/openstack/openstack-helm-plugin
```
### Create Workdir & define the openstack version

```bash
mkdir -p ~/osh/overrides
cd ~/osh

export OPENSTACK_RELEASE=2023.2
# Features enabled for the deployment. This is used to look up values overrides.
export FEATURES="${OPENSTACK_RELEASE} ubuntu_jammy"
# Directory where values overrides are looked up or downloaded to.
export OVERRIDES_DIR=$(pwd)/overrides
cd $OVERRIDES_DIR

```

### Labeling all nodes
```bash
kubectl label --overwrite nodes --all openstack-control-plane=enabled
kubectl label --overwrite nodes --all openstack-compute-node=enabled
kubectl label --overwrite nodes --all openvswitch=enabled
kubectl label --overwrite nodes --all openstack-network-node=enabled
kubectl taint nodes -l 'node-role.kubernetes.io/control-plane' node-role.kubernetes.io/control-plane-
```

### Install nginx ingress
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx oci://ghcr.io/nginx/charts/nginx-ingress \
    --version 2.1.0 \
    --namespace=ingress-nginx\
    --set controller.admissionWebhooks.enabled="false" \
    --set controller.replicaCount=1 \
    --set controller.ingressClassResource.name=nginx \
    --set controller.ingressClassResource.controllerValue="k8s.io/ingress-nginx" \
    --set controller.ingressClassResource.default="false" \
    --set controller.ingressClass.name=nginx \
    --set controller.labels.app=ingress-api \
    --set controller.service.create="true" \
    --set controller.hostNetwork=true
```
## Setup Password
go to [password](password.md)

## Setup Infra

```bash
helm install cert-manager jetstack/cert-manager --namespace cert-manager \
   --version v1.16.1 \
   --set installCRDs=true \
   --set extraArgs[0]="--enable-certificate-owner-ref=true" \
   --timeout=600s

tee cert-manager/self-cert.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
 name: humanz-cloud-selfsigned-issuer
spec:
 selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-cluster-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
 name: humanz-cloud-selfsigned-tls
spec:
 secretName: humanz-cloud-tls
 isCA: true
 issuerRef:
   name: humanz-cloud-selfsigned-issuer
   kind: Issuer
 commonName: "*.ctl1-humanz.cloud"
 dnsNames:
 - "*.ctl1-humanz.cloud"
EOF
kubectl -n openstack apply -f cert-manager/self-cert.yaml
kubectl get secret humanz-cloud-tls -n openstack -o jsonpath="{.data['tls\.crt']}" | base64 -d | sudo tee -a /etc/ssl/certs/ca-certificates.crt
```

### Rabbitmq
```bash
mkdir -p rabbitmq/values_overrides/
tee rabbitmq/values_overrides/password.yaml <<EOF
endpoints:
  oslo_messaging:
    auth:
      user:
        password: "$osh_rabbitmq_password"
EOF

helm upgrade --install rabbitmq openstack-helm/rabbitmq \
    --timeout=600s \
    --namespace=openstack \
    --set pod.replicas.server=1 \
    --set volume.class_name=ceph-rbd \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c rabbitmq ${FEATURES} values_overrides/password)

### Mariadb
mkdir -p mariadb/values_overrides/
tee mariadb/values_overrides/password.yaml <<EOF
endpoints:
  oslo_db:
    auth:
      admin:
        password: "$osh_mariadb_password"
EOF

helm upgrade --install mariadb openstack-helm/mariadb \
    --timeout=600s \
    --namespace=openstack \
    --set pod.replicas.server=1 \
    --set volume.class_name=ceph-rbd \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c mariadb ${FEATURES} values_overrides/password)

helm upgrade --install memcached openstack-helm/memcached \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c memcached ${FEATURES})
```

## Setup keystone
- [Keystone](setup/keystone.md)
- [Heat](setup/heat.md)
- [Glance](setup/glance.md)
- [Cinder](setup/cinder.md)
- [OpenvSwitch](setup/ovs.md)
- [OVN](setup/ovn.md)
- [Libvirt](setup/libvirt.md)
- [Palcement](setup/placement.md)
- [Nova](setup/nova.md)
- [Neutron](setup/neutron.md)
- [Horizon](setup/horizon.md)  

Exec it in order and if libvirt&nova pods isn't running or stuck at init you can ignore it until you deploy neutron 

Source: https://docs.openstack.org/openstack-helm/latest/install/openstack.html

---
```yaml
export clusterNamespace="openstack"
tee /tmp/ceph-mon.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ceph-mons
  namespace: $clusterNamespace
spec:
  ports:
    - name: ceph-mon-v2
      protocol: TCP
      port: 3300
      targetPort: 3300

    - name: ceph-mon-v1
      protocol: TCP
      port: 6789
      targetPort: 6789
---
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: ceph-mons-1
  namespace: $clusterNamespace
  labels:
    kubernetes.io/service-name: ceph-mons
addressType: IPv4
ports:
  - name: ceph-mon-v2
    protocol: TCP
    port: 3300
  - name: ceph-mon-v1
    protocol: TCP
    port: 6789
endpoints:
  - addresses:
      - "192.168.18.100"
EOF
```