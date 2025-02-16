ARG MAJOR_VERSION="${MAJOR_VERSION:-10-kitten}"

FROM ghcr.io/ublue-os/config:latest AS config
FROM ghcr.io/ublue-os/ucore:stable AS ucore
FROM quay.io/almalinuxorg/almalinux-bootc:$MAJOR_VERSION as base

# Install/remove packages to make an image with resembles Fedora CoreOS
COPY build.sh /tmp/build.sh
RUN --mount=type=bind,from=config,src=/rpms,dst=/tmp/rpms/config \
    --mount=type=bind,from=ucore,src=/usr/lib/systemd,dst=/tmp/ucore/systemd \
    --mount=type=bind,from=ucore,src=/usr/lib/tmpfiles.d,dst=/tmp/ucore/tmpfiles \
    --mount=type=bind,from=ucore,src=/etc,dst=/tmp/ucore/etc \
    --mount=type=bind,from=ucore,src=/usr/sbin,dst=/tmp/ucore/sbin \
    /tmp/build.sh && \
    dnf clean all && \
    ostree container commit

# Just gotta get this green!
RUN bootc container lint
