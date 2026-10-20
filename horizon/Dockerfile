FROM quay.io/airshipit/horizon:2025.2-ubuntu_noble
RUN apt update && \
    apt install python3-pip -y
RUN /var/lib/openstack/bin/python3 -m pip install \
    "octavia_dashboard~=14.0.0" "heat-dashboard~=12.0.0" "magnum-ui==17.0.0" \
    "python-magnumclient==4.9.0"
RUN cp /var/lib/openstack/lib/python3.12/site-packages/magnum_ui/enabled/_1370_project_container_infra_panel_group.py /usr/local/share/openstack_dashboard/enabled/ \
    && cp /var/lib/openstack/lib/python3.12/site-packages/magnum_ui/enabled/_1371_project_container_infra_clusters_panel.py /usr/local/share/openstack_dashboard/enabled/ \
    && cp /var/lib/openstack/lib/python3.12/site-packages/magnum_ui/enabled/_1372_project_container_infra_cluster_templates_panel.py /usr/local/share/openstack_dashboard/enabled/
RUN cd /var/lib/openstack/lib/python3.12/site-packages/openstack_dashboard && \
    /var/lib/openstack/bin/python3 manage.py collectstatic --noinput && \
    /var/lib/openstack/bin/python3 manage.py compress --force