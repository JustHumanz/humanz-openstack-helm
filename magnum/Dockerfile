FROM quay.io/airshipit/magnum:2025.2-ubuntu_noble
RUN apt update && \
    apt install python3-pip -y
RUN /var/lib/openstack/bin/python3 -m pip install magnum-capi-helm
RUN wget https://get.helm.sh/helm-v3.13.2-linux-amd64.tar.gz
RUN tar -zxvf helm-v3.13.2-linux-amd64.tar.gz
RUN mv linux-amd64/helm /usr/local/bin/
