#
# MT7621 Profiles
#

include ./common-tp-link.mk

DEFAULT_SOC := mt7621

KERNEL_DTB += -d21
DEVICE_VARS += ELECOM_HWNAME LINKSYS_HWNAME

define Build/elecom-wrc-gs-factory
	$(eval product=$(word 1,$(1)))
	$(eval version=$(word 2,$(1)))
	$(eval hash_opt=$(word 3,$(1)))
	$(MKHASH) md5 $(hash_opt) $@ >> $@
	( \
		echo -n "ELECOM $(product) v$(version)" | \
			dd bs=32 count=1 conv=sync; \
		dd if=$@; \
	) > $@.new
	mv $@.new $@
endef

define Build/gemtek-trailer
	printf "%s%08X" ".GEMTEK." "$$(cksum $@ | cut -d ' ' -f1)" >> $@
endef

define Build/hatlab-gateboard-combined
  rm -fR $@.bootfs.img

	mkfs.fat $@.bootfs.img -C 16384
	mcopy -i $@.bootfs.img $(IMAGE_KERNEL) ::vmlinux.itb

	PADDING="1" SIGNATURE="$(IMG_PART_SIGNATURE)" \
	GUID="$(IMG_PART_DISKGUID)" $(SCRIPT_DIR)/gen_image_generic.sh \
	$@ \
	$(CONFIG_TARGET_KERNEL_PARTSIZE) $@.bootfs.img \
	$(CONFIG_TARGET_ROOTFS_PARTSIZE) $(IMAGE_ROOTFS) \
	256
endef

define Build/h3c-blank-header
	dd if=/dev/zero of=$@.blank bs=160 count=1
	cat $@ >> $@.blank
	mv $@.blank $@
endef

define Build/hatlab-gateboard-kernel
	rm -fR $@.initrd
	rm -fR $@.initrd.cpio

	mkdir -p $@.initrd/{bin,dev,proc,sys,lib,etc}
	mkdir -p $@.initrd/lib/modules/$(LINUX_VERSION)

	$(CP) $(STAGING_DIR)/rdloader/bin/* $@.initrd/bin/
  $(CP) $(STAGING_DIR)/rdloader/lib/* $@.initrd/lib/
  $(CP) $(STAGING_DIR)/rdloader/etc/* $@.initrd/etc/

  $(RSTRIP) $@.initrd/bin/
  $(RSTRIP) $@.initrd/lib/

  chmod +x $@.initrd/bin/*
  ln -s ./bin/rdloader $@.initrd/init

	( \
		KMODS=(usb-common nls_base usbcore xhci-hcd xhci-mtk jbd2 mbcache ext4 scsi_mod usb-storage sd_mod mmc_core mmc_block mtk_sd crc32c_generic); \
		for kmod in "$${KMODS[@]}"; do \
			$(CP) \
				$(TARGET_DIR)/lib/modules/$(LINUX_VERSION)/$$kmod.ko \
				$@.initrd/lib/modules/$(LINUX_VERSION)/; \
			echo /lib/modules/$(LINUX_VERSION)/$$kmod.ko \
				>> $@.initrd/etc/rdloader_list; \
		done; \
	)

	( \
		if [ -f $(STAGING_DIR_HOST)/bin/cpio ]; then \
			CPIO=$(STAGING_DIR_HOST)/bin/cpio; \
		else \
			CPIO="cpio"; \
		fi; \
		cd $@.initrd; \
		find . | cpio -o -H newc -R 0:0 > $@.initrd.cpio; \
	)

	$(TOPDIR)/scripts/mkits.sh \
		-D $(DEVICE_NAME) -o $@.its -k $@ \
		-C gzip -d $(KDIR)/image-$(DEVICE_DTS).dtb \
		-i $@.initrd.cpio \
		-a $(KERNEL_LOADADDR) -e $(KERNEL_LOADADDR) \
		-c config-1 -A $(LINUX_KARCH) -v $(LINUX_VERSION)

	PATH=$(LINUX_DIR)/scripts/dtc:$(PATH) mkimage -f $@.its $@.new

	@mv $@.new $@
endef

define Build/iodata-factory
	$(eval fw_size=$(word 1,$(1)))
	$(eval fw_type=$(word 2,$(1)))
	$(eval product=$(word 3,$(1)))
	$(eval factory_bin=$(word 4,$(1)))
	if [ -e $(KDIR)/tmp/$(KERNEL_INITRAMFS_IMAGE) -a "$$(stat -c%s $@)" -lt "$(fw_size)" ]; then \
		$(CP) $(KDIR)/tmp/$(KERNEL_INITRAMFS_IMAGE) $(factory_bin); \
		$(STAGING_DIR_HOST)/bin/mksenaofw \
			-r 0x30a -p $(product) -t $(fw_type) \
			-e $(factory_bin) -o $(factory_bin).new; \
		mv $(factory_bin).new $(factory_bin); \
		$(CP) $(factory_bin) $(BIN_DIR)/; \
	else \
		echo "WARNING: initramfs kernel image too big, cannot generate factory image" >&2; \
	fi
endef

define Build/iodata-mstc-header
	( \
		data_size_crc="$$(dd if=$@ ibs=64 skip=1 2>/dev/null | gzip -c | \
			tail -c 8 | od -An -tx8 --endian little | tr -d ' \n')"; \
		echo -ne "$$(echo $$data_size_crc | sed 's/../\\x&/g')" | \
			dd of=$@ bs=8 count=1 seek=7 conv=notrunc 2>/dev/null; \
	)
	dd if=/dev/zero of=$@ bs=4 count=1 seek=1 conv=notrunc 2>/dev/null
	( \
		header_crc="$$(dd if=$@ bs=64 count=1 2>/dev/null | gzip -c | \
			tail -c 8 | od -An -N4 -tx4 --endian little | tr -d ' \n')"; \
		echo -ne "$$(echo $$header_crc | sed 's/../\\x&/g')" | \
			dd of=$@ bs=4 count=1 seek=1 conv=notrunc 2>/dev/null; \
	)
endef

define Build/sercomm-tag-factory
	$(eval magic_const=$(word 1,$(1)))
	dd if=/dev/zero count=$$((0x200)) bs=1 of=$@.head 2>/dev/null
	dd if=/dev/zero count=$$((0x70)) bs=1 2>/dev/null | tr '\000' '0' | \
		dd of=$@.head conv=notrunc 2>/dev/null
	printf $(SERCOMM_HWVER) | dd of=$@.head bs=1 conv=notrunc 2>/dev/null
	printf $(SERCOMM_HWID) | dd of=$@.head bs=1 seek=$$((0x8)) conv=notrunc 2>/dev/null
	printf $(SERCOMM_SWVER) | dd of=$@.head bs=1 seek=$$((0x64)) conv=notrunc \
		2>/dev/null
	dd if=$(IMAGE_KERNEL) skip=$$((0x100)) iflag=skip_bytes 2>/dev/null of=$@.clrkrn
	dd if=$(IMAGE_KERNEL) count=$$((0x100)) iflag=count_bytes 2>/dev/null of=$@.hdrkrn0
	dd if=/dev/zero count=$$((0x100)) iflag=count_bytes 2>/dev/null of=$@.hdrkrn1
	wc -c < $@.clrkrn | tr -d '\n' | dd of=$@.head bs=1 seek=$$((0x70)) \
		conv=notrunc 2>/dev/null
	stat -c%s $@ | tr -d '\n' | dd of=$@.head bs=1 seek=$$((0x80)) \
		conv=notrunc 2>/dev/null
	printf $(magic_const) | dd of=$@.head bs=1 seek=$$((0x90)) conv=notrunc 2>/dev/null
	cat $@.clrkrn $@ | md5sum | awk '{print $$1;}' | tr -d '\n' | dd of=$@.head bs=1 \
	seek=$$((0x1e0)) conv=notrunc 2>/dev/null
	cat $@.head $@.hdrkrn0 $@.hdrkrn1 $@.clrkrn $@ > $@.new
	mv $@.new $@
	rm $@.head $@.clrkrn
endef


define Build/ubnt-erx-factory-image
	if [ -e $(KDIR)/tmp/$(KERNEL_INITRAMFS_IMAGE) -a "$$(stat -c%s $@)" -lt "$(KERNEL_SIZE)" ]; then \
		echo '21001:7' > $(1).compat; \
		$(TAR) -cf $(1) --transform='s/^.*/compat/' $(1).compat; \
		\
		$(TAR) -rf $(1) --transform='s/^.*/vmlinux.tmp/' $(KDIR)/tmp/$(KERNEL_INITRAMFS_IMAGE); \
		$(MKHASH) md5 $(KDIR)/tmp/$(KERNEL_INITRAMFS_IMAGE) > $(1).md5; \
		$(TAR) -rf $(1) --transform='s/^.*/vmlinux.tmp.md5/' $(1).md5; \
		\
		echo "dummy" > $(1).rootfs; \
		$(TAR) -rf $(1) --transform='s/^.*/squashfs.tmp/' $(1).rootfs; \
		\
		$(MKHASH) md5 $(1).rootfs > $(1).md5; \
		$(TAR) -rf $(1) --transform='s/^.*/squashfs.tmp.md5/' $(1).md5; \
		\
		echo '$(BOARD) $(VERSION_CODE) $(VERSION_NUMBER)' > $(1).version; \
		$(TAR) -rf $(1) --transform='s/^.*/version.tmp/' $(1).version; \
		\
		$(CP) $(1) $(BIN_DIR)/; \
	else \
		echo "WARNING: initramfs kernel image too big, cannot generate factory image" >&2; \
	fi
endef

define Build/zytrx-header
	$(eval board=$(word 1,$(1)))
	$(eval version=$(word 2,$(1)))
	$(STAGING_DIR_HOST)/bin/zytrx -B '$(board)' -v '$(version)' -i $@ -o $@.new
	mv $@.new $@
endef

define Device/dsa-migration
  DEVICE_COMPAT_VERSION := 1.1
  DEVICE_COMPAT_MESSAGE := Config cannot be migrated from swconfig to DSA
endef

define Device/xiaomi_mi-router-4a-gigabit
  $(Device/dsa-migration)
  $(Device/uimage-lzma-loader)
  IMAGE_SIZE := 16064k
  DEVICE_VENDOR := Xiaomi
  DEVICE_MODEL := Mi Router 4A
  DEVICE_VARIANT := Gigabit Edition
  DEVICE_PACKAGES := kmod-mt7603 kmod-mt76x2
endef
TARGET_DEVICES += xiaomi_mi-router-4a-gigabit