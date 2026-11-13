FROM quay.io/airshipit/horizon:2025.2-ubuntu_noble
RUN apt-get update && \
    apt-get install --no-install-recommends python3-pip=24.0+dfsg-1ubuntu1.3 -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN /var/lib/openstack/bin/python3 -m pip install --no-cache-dir \
    "octavia_dashboard~=14.0.0" "heat-dashboard~=12.0.0" "magnum-ui==17.0.0" \
    "python-magnumclient==4.9.0" "masakari-dashboard==13.0.0" "python-masakariclient===8.7.0"
## Magnum UI
RUN cp /var/lib/openstack/lib/python3.12/site-packages/magnum_ui/enabled/_1370_project_container_infra_panel_group.py /usr/local/share/openstack_dashboard/enabled/ \
    && cp /var/lib/openstack/lib/python3.12/site-packages/magnum_ui/enabled/_1371_project_container_infra_clusters_panel.py /usr/local/share/openstack_dashboard/enabled/ \
    && cp /var/lib/openstack/lib/python3.12/site-packages/magnum_ui/enabled/_1372_project_container_infra_cluster_templates_panel.py /usr/local/share/openstack_dashboard/enabled/

## Masakari UI
RUN cp /var/lib/openstack/lib/python3.12/site-packages/masakaridashboard/local/enabled/_50_masakaridashboard.py /usr/local/share/openstack_dashboard/enabled/ \
    && cp /var/lib/openstack/lib/python3.12/site-packages/masakaridashboard/local/local_settings.d/_50_masakari.py /usr/local/share/openstack_dashboard/local/local_settings.d/

WORKDIR /var/lib/openstack/lib/python3.12/site-packages/openstack_dashboard     
RUN /var/lib/openstack/bin/python3 manage.py collectstatic --noinput && \
    /var/lib/openstack/bin/python3 manage.py compress --force