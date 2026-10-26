FROM quay.io/airshipit/masakari-monitors:2025.2-ubuntu_noble
USER root
RUN set -e; \
    if getent group haclient >/dev/null; then groupmod -g 189 haclient; else groupadd -r -g 189 haclient; fi; \
    if getent passwd hacluster >/dev/null; then usermod -u 189 -g 189 hacluster; \
    else useradd -r -u 189 -g haclient -s /sbin/nologin hacluster; fi; \
    apt-get update && apt-get install -y --no-install-recommends pacemaker-cli-utils; \
    rm -rf /var/lib/apt/lists/*