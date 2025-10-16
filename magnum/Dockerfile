FROM quay.io/airshipit/magnum:2025.1-ubuntu_noble
RUN pip install magnum-cluster-api
RUN wget https://get.helm.sh/helm-v3.13.2-linux-amd64.tar.gz
RUN tar -zxvf helm-v3.13.2-linux-amd64.tar.gz
RUN mv linux-amd64/helm /usr/local/bin/
