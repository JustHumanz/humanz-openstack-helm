Create BGP on mikrotik side
============================
```bash
/routing/bgp/connection/add name=PEER_humanz-pc as=64251 remote.as=64251 remote.address=192.168.20.250 hold-time=90 keepalive-time=30 local.address=humanz-bridge instance=cilium local.role=ibgp
/routing/bgp/connection/add name=PEER_ctl1.humanz as=64251 remote.as=64251 remote.address=192.168.20.100 hold-time=90 keepalive-time=30 local.address=humanz-bridge instance=cilium local.role=ibgp
```