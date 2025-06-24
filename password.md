## Set Password (RUN IT ONCE)

#### Infra
```bash
export osh_rabbitmq_password=$(pwgen -c 12 1)
export osh_mariadb_password=$(pwgen -c 12 1)
```

#### Keystone
```bash
export osh_mariadb_keystone_password=$(pwgen -c 12 1)
export osh_rabbitmq_keystone_password=$(pwgen -c 12 1)
export osh_os_admin_password=$(pwgen -c 12 1)
```

### Heat
```bash
export osh_mariadb_heat_password=$(pwgen -c 12 1)
export osh_rabbitmq_heat_password=$(pwgen -c 12 1)
export osh_os_heat_user_password=$(pwgen -c 12 1)
export osh_os_heat_trustee_password=$(pwgen -c 12 1)
export osh_os_heat_stack_user_password=$(pwgen -c 12 1)
```

### Glance
```bash
export osh_mariadb_glance_password=$(pwgen -c 12 1)
export osh_rabbitmq_glance_password=$(pwgen -c 12 1)
export osh_os_glance_user_password=$(pwgen -c 12 1)
```

### Cinder
```bash
export osh_mariadb_cinder_password=$(pwgen -c 12 1)
export osh_rabbitmq_cinder_password=$(pwgen -c 12 1)
export osh_os_cinder_user_password=$(pwgen -c 12 1)
export osh_os_cinder_nova_user_password=$(pwgen -c 12 1)
export osh_os_cinder_swift_user_password=$(pwgen -c 12 1)
export osh_os_cinder_service_user_password=$(pwgen -c 12 1)
```

### Placement
```bash
export osh_mariadb_nova_password=$(pwgen -c 12 1)
export osh_mariadb_placement_password=$(pwgen -c 12 1)
export osh_rabbitmq_placement_password=$(pwgen -c 12 1)
export osh_os_placement_user_password=$(pwgen -c 12 1)
```
### Nova
```bash
export osh_rabbitmq_nova_password=$(pwgen -c 12 1)
export osh_os_nova_user_password=$(pwgen -c 12 1)
export osh_os_nova_service_user_password=$(pwgen -c 12 1)
export osh_os_neutron_user_password=$(pwgen -c 12 1)
export osh_os_nova_placement_user_password=$(pwgen -c 12 1)
export osh_os_nova_cinder_user_password=$(pwgen -c 12 1)
```

### Neutron
```bash
export osh_os_neutron_placement_user_password=$(pwgen -c 12 1)
export osh_mariadb_neutron_password=$(pwgen -c 12 1)
export osh_rabbitmq_neutron_password=$(pwgen -c 12 1)
```

### Horizon
```bash
export osh_mariadb_horizon_password=$(pwgen -c 12 1)
export osh_rabbitmq_horizon_password=$(pwgen -c 12 1)
```

## Reuse Password

#### Infra
```bash
export osh_rabbitmq_password=$(yq '.endpoints.oslo_messaging.auth.user.password' rabbitmq/values_overrides/password.yaml)
export osh_mariadb_password=$(yq '.endpoints.oslo_db.auth.admin.password' mariadb/values_overrides/password.yaml)
```

#### Keystone
```bash
PASSWORD_FILE=keystone/values_overrides/password.yaml
export osh_mariadb_keystone_password=$(yq '.endpoints.oslo_db.auth.keystone.password' $PASSWORD_FILE)
export osh_rabbitmq_keystone_password=$(yq '.endpoints.oslo_messaging.auth.keystone.password' $PASSWORD_FILE)
export osh_os_admin_password=$(yq '.endpoints.identity.auth.admin.password' $PASSWORD_FILE)
```

### Heat
```bash
PASSWORD_FILE=heat/values_overrides/password.yaml
export osh_mariadb_heat_password=$(yq '.endpoints.oslo_db.auth.heat.password' $PASSWORD_FILE)
export osh_rabbitmq_heat_password=$(yq '.endpoints.oslo_messaging.auth.heat.password' $PASSWORD_FILE)
export osh_os_heat_user_password=$(yq '.endpoints.identity.auth.heat.password' $PASSWORD_FILE)
export osh_os_heat_trustee_password=$(yq '.endpoints.identity.auth.heat_trustee.password' $PASSWORD_FILE)
export osh_os_heat_stack_user_password=$(yq '.endpoints.identity.auth.heat_stack_user.password' $PASSWORD_FILE)
```

### Glance
```bash
PASSWORD_FILE=glance/values_overrides/password.yaml
export osh_mariadb_glance_password=$(yq '.endpoints.oslo_db.auth.glance.password' $PASSWORD_FILE)
export osh_rabbitmq_glance_password=$(yq '.endpoints.oslo_messaging.auth.glance.password' $PASSWORD_FILE)
export osh_os_glance_user_password=$(yq '.endpoints.identity.auth.glance.password' $PASSWORD_FILE)
```

### Cinder
```bash
PASSWORD_FILE=cinder/values_overrides/password.yaml
export osh_mariadb_cinder_password=$(yq '.endpoints.oslo_db.auth.cinder.password' $PASSWORD_FILE)
export osh_rabbitmq_cinder_password=$(yq '.endpoints.oslo_messaging.auth.cinder.password' $PASSWORD_FILE)
export osh_os_cinder_user_password=$(yq '.endpoints.identity.auth.cinder.password' $PASSWORD_FILE)
export osh_os_cinder_nova_user_password=$(yq '.endpoints.identity.auth.nova.password' $PASSWORD_FILE)
export osh_os_cinder_swift_user_password=$(yq '.endpoints.identity.auth.swift.password' $PASSWORD_FILE)
export osh_os_cinder_service_user_password=$(yq '.endpoints.identity.auth.service.password' $PASSWORD_FILE)
```

### Placement
```bash
PASSWORD_FILE=placement/values_overrides/password.yaml
export osh_mariadb_nova_password=$(yq '.endpoints.oslo_db.auth.nova_api.password' $PASSWORD_FILE)
export osh_mariadb_placement_password=$(yq '.endpoints.oslo_db.auth.placement.password' $PASSWORD_FILE)
export osh_rabbitmq_placement_password=$(yq '.endpoints.oslo_messaging.auth.placement.password' $PASSWORD_FILE)
export osh_os_placement_user_password=$(yq '.endpoints.identity.auth.placement.password' $PASSWORD_FILE)
```

### Nova
```bash
PASSWORD_FILE=placement/values_overrides/password.yaml
export osh_mariadb_nova_password=$(yq '.endpoints.oslo_db.auth.nova_api.password' $PASSWORD_FILE)

PASSWORD_FILE=nova/values_overrides/password.yaml
export osh_rabbitmq_nova_password=$(yq '.endpoints.oslo_messaging.auth.nova.password' $PASSWORD_FILE)
export osh_os_nova_user_password=$(yq '.endpoints.identity.auth.nova.password' $PASSWORD_FILE)
export osh_os_nova_service_user_password=$(yq '.endpoints.identity.auth.service.password' $PASSWORD_FILE)
export osh_os_neutron_user_password=$(yq '.endpoints.identity.auth.neutron.password' $PASSWORD_FILE)
export osh_os_nova_placement_user_password=$(yq '.endpoints.identity.auth.placement.password' $PASSWORD_FILE)
export osh_os_nova_cinder_user_password=$(yq '.endpoints.identity.auth.cinder.password' $PASSWORD_FILE)
```

### Neutron
```bash
PASSWORD_FILE=nova/values_overrides/password.yaml
export osh_os_nova_service_user_password=$(yq '.endpoints.identity.auth.service.password' $PASSWORD_FILE)

PASSWORD_FILE=neutron/values_overrides/password.yaml
export osh_os_neutron_placement_user_password=$(yq '.endpoints.identity.auth.placement.password' $PASSWORD_FILE)
export osh_mariadb_neutron_password=$(yq '.endpoints.oslo_db.auth.neutron.password' $PASSWORD_FILE)
export osh_rabbitmq_neutron_password=$(yq '.endpoints.oslo_messaging.auth.neutron.password' $PASSWORD_FILE)
```

### Horizon
```bash
PASSWORD_FILE=horizon/values_overrides/password.yaml
export osh_mariadb_horizon_password=$(yq '.endpoints.oslo_db.auth.horizon.password' $PASSWORD_FILE)
export osh_rabbitmq_horizon_password=$(yq '.endpoints.oslo_messaging.auth.horizon.password' $PASSWORD_FILE)
```