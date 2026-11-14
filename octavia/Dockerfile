FROM quay.io/airshipit/octavia:2025.2-ubuntu_noble
RUN apt-get update && \
    apt-get install --no-install-recommends python3-pip=24.0+dfsg-1ubuntu1.3 -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN /var/lib/openstack/bin/python3 -m pip install --no-cache-dir ovn-octavia-provider==9.0.0