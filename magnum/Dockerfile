FROM quay.io/airshipit/magnum:2025.2-ubuntu_noble
RUN apt-get update && \
    apt-get install python3-pip -y
RUN /var/lib/openstack/bin/python3 -m pip install magnum-capi-helm && \
    wget --progress=dot:giga https://get.helm.sh/helm-v3.13.2-linux-amd64.tar.gz && \
    tar -zxvf helm-v3.13.2-linux-amd64.tar.gz && \
    mv linux-amd64/helm /usr/local/bin/