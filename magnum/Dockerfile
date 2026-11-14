FROM quay.io/airshipit/magnum:2025.2-ubuntu_noble
RUN apt-get update \
    && apt-get install --no-install-recommends python3-pip=24.0+dfsg-1ubuntu1.3 -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN /var/lib/openstack/bin/python3 -m pip install --no-cache-dir magnum-capi-helm \
    && wget --progress=dot:giga https://get.helm.sh/helm-v3.13.2-linux-amd64.tar.gz \
    && tar -zxvf helm-v3.13.2-linux-amd64.tar.gz \
    && mv linux-amd64/helm /usr/local/bin/