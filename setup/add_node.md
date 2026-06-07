### Join a compute node

On new Node
```bash
/usr/local/bin/kubeadm join 192.168.18.100:6443 --token XXXXXXX.YYYYYYYYY --discovery-token-ca-cert-hash sha256:XXXXXXXXXXXXXXXXXX --ignore-preflight-errors=Swap
```

On controller
```bash
kubectl label node {NODE_NAME} node-role.kubernetes.io/worker=worker
kubectl label node {NODE_NAME} openvswitch=enabled
kubectl label node {NODE_NAME} openstack-compute-node=enabled
kubectl get nodes --show-labels
```