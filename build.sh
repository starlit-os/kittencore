#!/usr/bin/env bash

set -euox pipefail

dnf -y update
dnf -y install 'dnf-command(versionlock)'
dnf versionlock add kernel kernel-devel kernel-devel-matched kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-uki-virt

dnf -y install 'dnf-command(config-manager)'
dnf config-manager --set-enabled crb
dnf -y install epel-release

# Install ublue-os stuff
dnf install -y \
    /tmp/rpms/config/ublue-os-{luks,udev-rules}.noarch.rpm

# add some packages present in Fedora CoreOS but not CentOS bootc
dnf -y install --setopt=install_weak_deps=False \
  afterburn \
  afterburn-dracut \
  audit \
  authselect \
  clevis-dracut \
  clevis-pin-tpm2 \
  coreos-installer \
  coreos-installer-bootinfra \
  firewalld \
  git-core \
  hwdata \
  ignition \
  ipcalc \
  iscsi-initiator-utils \
  nfs-utils-coreos \
  rsync \
  ssh-key-dir \
  wireguard-tools
# TODO: Add these if/when available
# NetworkManager-team \
# runc \


# Fix some missing directories and files
mkdir -p /var/lib/rpm-state
touch /var/lib/rpm-state/nfs-server.cleanup
#mkdir -p /var/lib/gssproxy/{rcache,clients}

# remove some packages present in CentOS bootc but not Fedora CoreOS
dnf -y remove \
  gssproxy \
  nfs-utils \
  quota \
  quota-nls

# apply CoreOS overlays
cd /tmp/
git clone https://github.com/coreos/fedora-coreos-config
cd fedora-coreos-config
git checkout stable
cd overlay.d
# remove overlays which should not be used on CentOS
# no composefs by default on CentoOS stream9
rm -fr 08composefs
# remove fedora specific stuff
rm -fr 15fcos/usr/lib/dracut
rm -fr 15fcos/usr/lib/motd.d
rm -fr 15fcos/usr/lib/systemd
rm -fr 15fcos/usr/libexec
# zincati should not even exist in a bootc image
rm -fr 16disable-zincati
# now try to apply
for od in $(find * -maxdepth 0 -type d); do
  pushd ${od}
  find * -maxdepth 0 -type d -exec rsync -av ./{}/ /{}/ \;
  if [ -f statoverride ]; then
    for line in $(grep ^= statoverride|sed 's/ /=/'); do
      DEC=$(echo $line|cut -f2 -d=)
      OCT=$(printf %o ${DEC})
      FILE=$(echo $line|cut -f3 -d=)
      chmod ${OCT} ${FILE}
    done
  fi
  popd
done

# enable systemd-resolved for proper name resolution
systemctl enable systemd-resolved.service

# Copy ucore workaround services and enable them
cp /tmp/ucore/systemd/system/{libvirt,swtpm}-workaround.service /usr/lib/systemd/system/
cp /tmp/ucore/tmpfiles/{libvirt,swtpm}-workaround.conf /usr/lib/tmpfiles.d/
cp /tmp/ucore/systemd/system/ucore-paths-provision.service /usr/lib/systemd/system/
cp /tmp/ucore/etc/systemd/ucore-paths-provision.conf /etc/systemd/
cp /tmp/ucore/sbin/ucore-paths-provision.sh /usr/sbin/

systemctl enable libvirt-workaround.service
systemctl enable swtpm-workaround.service
systemctl enable ucore-paths-provision.service
