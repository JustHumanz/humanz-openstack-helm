# kubeadm/upgrade_cluster.yml

This playbook upgrades a kubeadm-managed Kubernetes cluster and uses a role to install kubeadm/kubelet/kubectl across distros.

Overview
- The playbook expects two inventory groups: `kube_control_plane` and `kube_node`.
- It upgrades control-plane nodes first (serial: 1), then worker nodes (serial: 1).

Variables
- `target_k8s_version` (required): target Kubernetes version to upgrade to. Example: `v1.26.3`.
- `kubeadm_kubeconfig` (optional): path to kubeconfig on control-plane (default `/etc/kubernetes/admin.conf`).

Role behavior
- For `Ubuntu`/`Debian`: the role updates `/etc/apt/sources.list.d/kubernetes.list` to point at the appropriate `core:/stable:/vX.Y` apt repo (derived from `target_k8s_version`), then installs `kubeadm`, `kubelet`, and `kubectl` packages at the matching version.
- For other Linux distros: the role downloads the binaries from `https://dl.k8s.io/release/<version>/bin/linux/amd64/` and places them in `/usr/bin` (configurable).

Usage
From your repository root run:

```bash
ansible-playbook -i inventory kubeadm/upgrade_cluster.yml -e "target_k8s_version=v1.26.3"
```

Notes and assumptions
- The nodes should be able to reach `https://pkgs.k8s.io/` (for Debian/Ubuntu apt) and `https://dl.k8s.io/` (for binary downloads).
- The user running the playbook needs `become` privileges on the target hosts.
- The control-plane kubeconfig must be present and usable by the control-plane node(s).
- Test this in a staging environment before using in production.

If you want, I can:
- Update the playbook to add apt repo configuration if missing.
- Add safer checks (cordon/un-drain verification, rollback steps).
