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

kubectl get secret humanz-cloud-tls -n openstack -o jsonpath="{.data['tls\.crt']}" | base64 -d | sudo tee -a /etc/ssl/certs/ca-certificates.crt

### Rabbitmq
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
