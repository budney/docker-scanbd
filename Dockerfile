#
#===============================================================================
#
FROM debian
LABEL maintainer="Len Budney (len.budney@gmail.com)"

ARG USERNAME=scanbd
ARG USER_UID=65526
ARG USER_GID=${USER_UID}

COPY fujitsu.conf scan.script entry.sh daemons scanbd_dbus.conf scanbd.conf \
    dropbox_uploader \
    /tmp/

RUN apt update && apt install -y \
    ucspi-tcp \
    daemontools \
    scanbd \
    sane \
    sane-utils \
    netpbm \
    ghostscript \
    poppler-utils \
    imagemagick \
    unpaper \
    util-linux \
    tesseract-ocr \
#    parallel \
#    units \
    bc \
    curl \
    udev \
    exactimage \
    pdftk \
    && groupadd -g ${USER_GID} ${USERNAME} \
    && useradd -d / -M -s /bin/true -g ${USER_GID} -u ${USER_UID} ${USERNAME} \
    && chmod 0755 /tmp/scan.script /tmp/entry.sh /tmp/dropbox_uploader \
    && cp -f /tmp/scanbd.conf /etc/scanbd/ \
    && cp -f /tmp/fujitsu.conf /etc/scanbd/scanner.d/ \
    && cp -f /tmp/scan.script /usr/share/scanbd/scripts/ \
    && cp -f /tmp/entry.sh /usr/bin/entry.sh \
    && cp -f /tmp/scanbd_dbus.conf /etc/dbus-1/system.d/ \
    && cp -f /tmp/dropbox_uploader /usr/local/bin \
    && mkdir /etc/scanbd/daemons \
    && mv /tmp/scan-* /etc/scanbd/daemons/ \
    && rm -rf /var/spool/scan /var/spool/archive \
    && mkdir -m 03700 /var/spool/scan /var/spool/archive \
    && ln -s /var/spool/scan /etc/scanbd/daemons/scan-processor/work \
    && ln -s /var/spool/archive /etc/scanbd/daemons/scan-processor/archive \
    && chown -R ${USERNAME}:${USERNAME} /etc/scanbd/daemons/*/work /var/spool/scan /var/spool/archive \
    && ln -s /etc/scanbd/daemons/* /srv/ \
    && ln -s /srv /service

ENV DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
ENV UDEV off

ENTRYPOINT ["/usr/bin/entry.sh"]

