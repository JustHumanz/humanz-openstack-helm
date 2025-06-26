# Setup helm manifest


### Swift
```bash
SERVICE_DOMAIN_ID=$(openstack domain show service -c id -f value)
SERVICE_PROJECT_ID=$(openstack project show service -c id -f value)
openstack user create --project $SERVICE_PROJECT_ID --domain $SERVICE_DOMAIN_ID --description "Service User for RegionOne/service/swift" --password $osh_os_swift_user_password swift
SWIFT_USER_ID=$(openstack user show swift --domain $SERVICE_DOMAIN_ID -c id -f value)

openstack role add --user $SWIFT_USER_ID --project $SERVICE_PROJECT_ID $(openstack role show admin -c id -f value)
openstack role add --user $SWIFT_USER_ID --project $SERVICE_PROJECT_ID $(openstack role show service -c id -f value)
openstack role add --user $SWIFT_USER_ID --project $SERVICE_PROJECT_ID $(openstack role show member -c id -f value)

kubectl -n openstack create secret generic swift-openrc \
  --from-literal=OS_AUTH_URL=http://keystone-api.openstack.svc.cluster.local:5000/v3 \
  --from-literal=OS_AUTH_TYPE=password \
  --from-literal=OS_IDENTITY_API_VERSION=3 \
  --from-literal=OS_PASSWORD=$osh_os_swift_user_password \
  --from-literal=OS_PROJECT_DOMAIN_NAME=service \
  --from-literal=OS_PROJECT_NAME=service \
  --from-literal=OS_USER_DOMAIN_NAME=service \
  --from-literal=OS_INTERFACE=internal \
  --from-literal=OS_USERNAME=swift


tee swift/rook-rgw.yaml <<EOF
apiVersion: ceph.rook.io/v1
kind: CephObjectStore
metadata:
  name: swift
  namespace: openstack
spec:
  metadataPool:
    failureDomain: osd
    replicated:
      size: 1
  dataPool:
    failureDomain: osd
    erasureCoded:
      dataChunks: 2
      codingChunks: 1
  auth:
    keystone:
      acceptedRoles:
        - admin
        - member
        - service
      implicitTenants: "swift"
      revocationInterval: 1200
      serviceUserSecretName: swift-openrc
      tokenCacheSize: 1000
      url: http://keystone-api.openstack.svc.cluster.local:5000
  protocols:
    swift:
      accountInUrl: true
      urlPrefix: swift
    # note that s3 is enabled by default if protocols.s3.enabled is not explicitly set to false
  preservePoolsOnDelete: true
  gateway:
    sslCertificateRef:
    port: 80
    # securePort: 443
    instances: 1
EOF

kubectl get CephObjectStore -n openstack

tee swift/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  name: swift
  namespace: openstack
spec:
  tls:
    - hosts:
        - "swift.ctl1-humanz.cloud"
      secretName: humanz-cloud-tls
  ingressClassName: nginx
  rules:
  - host: swift.ctl1-humanz.cloud
    http:
      paths:
      - backend:
          service:
            name: rook-ceph-rgw-swift
            port:
              number: 80
        path: /
        pathType: Prefix
EOF
kubectl apply -f swift/ingress.yaml

openstack service create --name swift object-store
openstack endpoint create --region RegionOne --enable swift admin "http://rook-ceph-rgw-swift.openstack.svc/swift/v1/AUTH_%(project_id)s"
openstack endpoint create --region RegionOne --enable swift internal "http://rook-ceph-rgw-swift.openstack.svc/swift/v1/AUTH_%(project_id)s"
openstack endpoint create --region RegionOne --enable swift public "https://swift.ctl1-humanz.cloud/swift/v1/AUTH_%(project_id)s"
```
