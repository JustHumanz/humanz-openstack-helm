```
openstack network create octavia-mgmt-net --project service
openstack subnet create --network octavia-mgmt-net --subnet-range 10.10.10.0/23 octavia-mgmt-subnet --dns-nameserver 10.96.0.10 --project service
openstack port create --network octavia-mgmt-net octavia-worker-port-ctl1-humanz
openstack port create --network octavia-mgmt-net octavia-health-manager-port-ctl1-humanz
openstack image create --project service --tag octavia-amphora-image --file octavia-amphora-haproxy-2025.2.img --disk-format raw --progress octavia-amphora-haproxy
openstack flavor create --ram 1024 --disk 10 --vcpus 1 --project service --private m1.amphora
openstack security group create lb-mgmt-sec-grp --project service
openstack security group rule create --protocol icmp lb-mgmt-sec-grp
openstack security group rule create --protocol tcp --dst-port 22 lb-mgmt-sec-grp
openstack security group rule create --protocol tcp --dst-port 9443 lb-mgmt-sec-grp
```