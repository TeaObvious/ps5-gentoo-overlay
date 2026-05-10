# ps5-gentoo-overlay

Gentoo overlay for PlayStation 5 Linux.

Packages:

- `sys-kernel/ps5-sources`: live ebuild that fetches the Linux stable tree, applies `ps5-linux/ps5-linux-patches`, installs the upstream PS5 `.config`, installs a genkernel configuration, and provides PS5 boot helper scripts.
- `app-misc/ps5-tools`: live ebuild for `ps5_control`, `m2_init`, `ps5-m2-exec`, and `ps5-m2-install`.

## Add overlay

This overlay is synced through Git. Make sure Git is installed first:

```bash
sudo emerge --ask dev-vcs/git
```

Create the Portage repository configuration:

```bash
sudo mkdir -p /etc/portage/repos.conf
sudo tee /etc/portage/repos.conf/ps5-gentoo.conf >/dev/null <<'CONF'
[ps5-gentoo]
location = /var/db/repos/ps5-gentoo
sync-type = git
sync-uri = https://github.com/TeaObvious/ps5-gentoo-overlay.git
masters = gentoo
auto-sync = yes
priority = 50
CONF

sudo emaint sync -r ps5-gentoo
```

The overlay will also be synced by the normal Portage sync:

```bash
sudo emerge --sync
```

## Accept live ebuilds

The packages are live ebuilds and therefore unkeyworded. Accept them locally first:

```bash
sudo mkdir -p /etc/portage/package.accept_keywords
sudo tee /etc/portage/package.accept_keywords/ps5 >/dev/null <<'EOF_KEYWORDS'
=sys-kernel/ps5-sources-9999 **
=app-misc/ps5-tools-9999 **
EOF_KEYWORDS
```

## Install

Install the PS5 kernel sources and tools:

```bash
sudo emerge --ask sys-kernel/ps5-sources app-misc/ps5-tools
```

The `ps5-tools` package has optional `openrc` and `systemd` USE flags for service installation.

Do not force these globally unless needed. Let your Gentoo profile and system configuration decide. If you need PS5-specific USE overrides later, put them in:

```text
/etc/portage/package.use/ps5
```

## Build kernel with genkernel

Select the installed PS5 kernel sources:

```bash
eselect kernel list
sudo eselect kernel set <number-for-linux-*-ps5>
```

Build kernel and initramfs with genkernel:

```bash
sudo genkernel --kernel-config=/usr/src/linux/.config --no-menuconfig --no-mrproper --oldconfig all
```

## Boot partition assumption

This overlay assumes that the PS5 Linux boot partition is mounted at:

```text
/boot/efi
```

`ps5-install-bootfiles` uses `/boot/efi` as its default target.

For USB-based setups, this means that the boot partition of the external USB device must be mounted at `/boot/efi` inside the Gentoo system or chroot before running:

```bash
sudo ps5-install-bootfiles
```

Example:

```bash
sudo mkdir -p /boot/efi
sudo mount /dev/sdX1 /boot/efi
sudo ps5-install-bootfiles
```

The mount point can also be overridden by passing a different target directory:

```bash
sudo ps5-install-bootfiles /path/to/ps5/boot/partition
```

## Boot files

After genkernel has built the kernel and initramfs, copy the boot files to the mounted PS5 Linux boot partition:

```bash
sudo ps5-install-bootfiles /boot/efi
```

Default output names:

```text
bzImage-gentoo
initrd-gentoo.img
```

Single-system mode:

```bash
sudo ps5-install-bootfiles --single /boot/efi
```

Single-system output names:

```text
bzImage
initrd.img
```

During first setup, the helper can create:

```text
kexec-gentoo.sh
cmdline-gentoo.txt
```

## Gentoo kexec entry

Default mode creates a Gentoo kexec entry using:

```text
/boot/efi/bzImage-gentoo
/boot/efi/initrd-gentoo.img
/boot/efi/cmdline-gentoo.txt
```

Single-system mode creates a Gentoo kexec entry using:

```text
/boot/efi/bzImage
/boot/efi/initrd.img
/boot/efi/cmdline-gentoo.txt
```

The generated file looks like this in default mode:

```sh
#!/bin/sh
# Switch to Gentoo Linux via kexec
set -e

BOOT=/boot/efi

kexec -l "$BOOT/bzImage-gentoo" \
	--initrd="$BOOT/initrd-gentoo.img" \
	--command-line="$(cat "$BOOT/cmdline-gentoo.txt")"

kexec -e
```

## Kernel command line

`ps5-install-bootfiles` can create `cmdline-gentoo.txt` during first setup.

The default generated command line is:

```text
root=LABEL=gentoo rw rootwait
```

For an ext4 root filesystem, you can set the matching label like this:

```bash
sudo e2label /dev/sdX2 gentoo
```

For a btrfs root filesystem, you can set the matching label like this:

```bash
sudo btrfs filesystem label /mountpoint gentoo
```

To generate a different label during first setup:

```bash
sudo PS5_ROOT_LABEL=myroot ps5-install-bootfiles /boot/efi
```

To generate a completely custom command line during first setup:

```bash
sudo PS5_CMDLINE='root=UUID=1234-5678 rw rootwait' ps5-install-bootfiles /boot/efi
```

After first setup, edit the file directly if needed:

```bash
sudo nano /boot/efi/cmdline-gentoo.txt
```

## Notes

This overlay uses live ebuilds.

That means the ebuilds fetch the current upstream Git repositories when they are emerged. Re-emerging the package can therefore pull newer upstream commits.

For a reproducible system, pin the ebuilds or create versioned ebuilds once a known-good PS5 Linux setup is confirmed.
