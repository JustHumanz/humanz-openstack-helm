kubectl create ns openstack
kubectl create ns ingress-nginx
kubectl taint nodes -l 'node-role.kubernetes.io/control-plane' node-role.kubernetes.io/control-plane-
 
mkdir -p /opt/cephadm;cd /opt/cephadm
curl --silent --remote-name --location https://github.com/ceph/ceph/raw/quincy/src/cephadm/cephadm
chmod +x cephadm
./cephadm add-repo --release reef
./cephadm install
cephadm install ceph-common
mkdir -p /etc/ceph
cephadm bootstrap --mon-ip 38.129.16.38
sudo apparmor_parser -R /etc/apparmor.d/MongoDB_Compass

fallocate /var/lib/openstack-helm/osdX.img -l X0G
losetup /dev/loopX0 /var/lib/openstack-helm/osdX.img
ceph orch daemon add osd $HOSTNAME:/dev/loop10 raw
ceph config set global mon_allow_pool_size_one true
ceph config set global mon_allow_pool_delete true

ceph osd pool create kube replicated_rule 32 32
ceph osd pool application enable kube rbd
ceph osd pool set kube size 1 --yes-i-really-mean-it

ip link add fip type dummy
ip add add 172.16.18.1/24 dev fip
ip link set fip up

curl -s https://raw.githubusercontent.com/rook/rook/release-1.17/deploy/examples/create-external-cluster-resources.py > create-external-cluster-resources.py
python3 create-external-cluster-resources.py --rbd-data-pool-name kube --namespace rook-ceph-external --format bash
>export NAMESPACE=rook-ceph-external
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
export clusterNamespace="rook-ceph-external"
curl -s https://raw.githubusercontent.com/rook/rook/release-1.17/deploy/charts/rook-ceph/values.yaml > values.yaml
curl -s https://raw.githubusercontent.com/rook/rook/release-1.17/deploy/charts/rook-ceph-cluster/values-external.yaml > values-external.yaml
helm install --create-namespace --namespace $operatorNamespace rook-ceph rook-release/rook-ceph -f values.yaml
helm install --create-namespace --namespace $clusterNamespace rook-ceph-cluster \
--set operatorNamespace=$operatorNamespace rook-release/rook-ceph-cluster -f values-external.yaml

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

helm repo add openstack-helm https://tarballs.opendev.org/openstack/openstack-helm
helm plugin install https://opendev.org/openstack/openstack-helm-plugin

mkdir ~/osh
cd ~/osh
git clone https://opendev.org/openstack/openstack-helm.git
git clone https://opendev.org/zuul/zuul-jobs.git


kubectl label --overwrite nodes --all openstack-control-plane=enabled
kubectl label --overwrite nodes --all openstack-compute-node=enabled
kubectl label --overwrite nodes --all openvswitch=enabled
kubectl label --overwrite nodes --all openstack-network-node=enabled


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

export OPENSTACK_RELEASE=2023.2
# Features enabled for the deployment. This is used to look up values overrides.
export FEATURES="${OPENSTACK_RELEASE} ubuntu_jammy"
# Directory where values overrides are looked up or downloaded to.
export OVERRIDES_DIR=$(pwd)/overrides

tee ${OVERRIDES_DIR}/domain.yml <<EOF
endpoints:
  identity:
    host_fqdn_override:
      public:
        host: "cinder.ctl1-humanz.cloud"
  cloudformation:
    host_fqdn_override:
      public:
        host: "cloudformation.ctl1-humanz.cloud"
  orchestration:
    host_fqdn_override:
      public:
        host: "heat.ctl1-humanz.cloud"
  image:
    host_fqdn_override:
      public:
        host: "glance.ctl1-humanz.cloud"
  dashboard:
    host_fqdn_override:
      public:
        host: "horizon.ctl1-humanz.cloud"
  volumev3:
    host_fqdn_override:
      public:
        host: "cinder.ctl1-humanz.cloud"
  compute:
    host_fqdn_override:
      public:
        host: "nova.ctl1-humanz.cloud"
  compute_novnc_proxy:
    host_fqdn_override:
      public:
        host: "vnc.ctl1-humanz.cloud"
  network:
    host_fqdn_override:
      public:
        host: "neutron.ctl1-humanz.cloud"
EOF

tee ${OVERRIDES_DIR}/network_backend.yml <<EOF
network:
  backend:
    - ovn
EOF

tee ${OVERRIDES_DIR}/volume.yml <<EOF
volume:
  class_name: ceph-rbd
  ovn_ovsdb_nb:
    class_name: ceph-rbd
  ovn_ovsdb_sb:
    class_name: ceph-rbd  
EOF

cd ${OVERRIDES_DIR}

helm upgrade --install rabbitmq openstack-helm/rabbitmq --namespace=openstack \
    --set pod.replicas.server=1 \
    --timeout=600s \
    --values rabbitmq/2023.2-ubuntu_jammy.yaml \
    --values volume.yml

helm upgrade --install mariadb openstack-helm/mariadb --namespace=openstack\
     --set pod.replicas.server=1 \
     --timeout=600s \
     --values volume.yml

helm upgrade --install memcached openstack-helm/memcached --namespace=openstack 

helm upgrade --install keystone openstack-helm/keystone --namespace=openstack \
     --values keystone/2023.2-ubuntu_jammy.yaml \
     --timeout=600s \
     --values domain.yml

helm upgrade --install heat openstack-helm/heat --namespace=openstack \
     --values heat/2023.2-ubuntu_jammy.yaml \
     --timeout=600s \
     --values domain.yml


mkdir ${OVERRIDES_DIR}/glance/values_overrides/
tee ${OVERRIDES_DIR}/glance/values_overrides/glance_pvc_storage.yaml <<EOF
storage: rbd
volume:
  class_name: ceph-rbd
  size: 10Gi
EOF

tee ${OVERRIDES_DIR}/glance/values_overrides/glance_conf.yaml <<EOF
conf:
  glance:
    rbd:
      rbd_store_chunk_size: 8
      rbd_store_replication: 1
      rbd_store_crush_rule: replicated_rule
EOF


helm upgrade --install glance openstack-helm/glance \
    --namespace=openstack \
    --timeout=600s \
    --values glance/2023.2-ubuntu_jammy.yaml \
    --values glance/values_overrides/glance_pvc_storage.yaml \
    --values glance/values_overrides/glance_conf.yaml \
    --values domain.yml

mkdir ${OVERRIDES_DIR}/cinder/values_overrides/
tee ${OVERRIDES_DIR}/cinder/values_overrides/cinder_conf.yaml <<EOF
conf:
  ceph:
    pools:
      backup:
        replication: 1
      cinder.volumes:
        replication: 1
EOF

helm upgrade --install cinder openstack-helm/cinder \
    --namespace=openstack \
    --timeout=600s \
    --values cinder/2023.2-ubuntu_jammy.yaml \
    --values cinder/values_overrides/cinder_conf.yaml \
    --values domain.yml

mkdir ${OVERRIDES_DIR}/openvswitch/values_overrides/
tee ${OVERRIDES_DIR}/openvswitch/values_overrides/openvswitch_conf.yaml <<EOF
---
conf:
  openvswitch_db_server:
    ptcp_port: 6640
EOF
helm upgrade --install openvswitch openstack-helm/openvswitch \
    --timeout=600s \
    --namespace=openstack \
    --values openvswitch/ubuntu_jammy.yaml \
    --values openvswitch/values_overrides/openvswitch_conf.yaml

helm upgrade --install libvirt openstack-helm/libvirt \
    --namespace=openstack \
    --timeout=600s \
    --set conf.ceph.enabled=true \
    --values libvirt/2023.2-ubuntu_jammy.yaml \
    --values network_backend.yml 

helm upgrade --install placement openstack-helm/placement \
    --namespace=openstack \
    --timeout=600s \
    --values placement/2023.2-ubuntu_jammy.yaml \
    --values domain.yml

helm upgrade --install nova openstack-helm/nova \
    --namespace=openstack \
    --set bootstrap.wait_for_computes.enabled=true \
    --set conf.ceph.enabled=true \
    --values nova/2023.2-ubuntu_jammy.yaml \
    --values nova/values_overrides/nova_conf.yml \
    --values network_backend.yml \
    --values domain.yml

mkdir -p ${OVERRIDES_DIR}/ovn/values_overrides
tee ${OVERRIDES_DIR}/ovn/values_overrides/ovn-conf.yaml << EOF
conf:
  ovn_cms_options: "enable-chassis-as-gw,availability-zones=nova"
  ovn_bridge_mappings: public:br-ex
  auto_bridge_add:
    br-ex: fip
EOF

helm upgrade --install ovn openstack-helm/ovn \
    --namespace=openstack \
    --values ovn/ubuntu_jammy.yaml \
    --values ovn/values_overrides/volume.yml \
    --values volume.yml

mkdir -p ${OVERRIDES_DIR}/neutron/values_overrides
tee ${OVERRIDES_DIR}/neutron/values_overrides/neutron_config.yaml << EOF
---
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

manifests:
  daemonset_dhcp_agent: false
  daemonset_l3_agent: false
  daemonset_metadata_agent: false
  daemonset_ovs_agent: false
  deployment_rpc_server: false

  daemonset_ovn_metadata_agent: true   
EOF

helm upgrade --install neutron openstack-helm/neutron \
    --namespace=openstack \
    --values neutron/2023.2-ubuntu_jammy.yaml \
    --values neutron/values_overrides/neutron_config.yaml \
    --values domain.yml


helm upgrade --install horizon openstack-helm/horizon \
    --namespace=openstack \
    --values horizon/2023.2-ubuntu_jammy.yaml \
    --values domain.yml



---

apiVersion: v1
kind: Service
metadata:
  name: ceph-mons
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