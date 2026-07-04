FROM ghcr.io/ublue-os/ucore-minimal:stable

COPY system_files/ /
COPY build_files/build.sh /tmp/build.sh

RUN /tmp/build.sh && \
    rm -f /tmp/build.sh && \
    ostree container commit
