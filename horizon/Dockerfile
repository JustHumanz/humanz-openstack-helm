FROM quay.io/airshipit/horizon:2025.2-ubuntu_noble
RUN apt update && \
    apt install python3-pip -y
RUN /var/lib/openstack/bin/python3 -m pip install "octavia_dashboard~=14.0.0" "heat-dashboard~=12.0.0"