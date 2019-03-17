WIREGUARD_VERSION ?= 0.0.20190227
LIBMNL_VERSION ?= 1.0.4

LIBMNL_TAR = libmnl-$(LIBMNL_VERSION).tar.bz2
LIBMNL_DIR = libmnl-$(LIBMNL_VERSION)

WIREGUARD_TAR = WireGuard-$(WIREGUARD_VERSION).tar.xz
WIREGUARD_DIR = WireGuard-$(WIREGUARD_VERSION)

WG_TARGET = $(WIREGUARD_DIR)/src/tools/wg
WG_QUICK_TARGET = $(WIREGUARD_DIR)/wg-quick
WG_MODULE_TARGET = $(WIREGUARD_DIR)/src/wireguard.ko

ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

all: $(WG_TARGET) $(WG_QUICK_TARGET) $(WG_MODULE_TARGET)

$(LIBMNL_TAR):
	wget https://netfilter.org/projects/libmnl/files/$(LIBMNL_TAR)

$(LIBMNL_DIR)/Makefile: $(LIBMNL_TAR)
	tar -xf $(LIBMNL_TAR)
	(cd $(LIBMNL_DIR) && ./configure --host=x86_64-unknown-linux-gnu --enable-static --target=arm-unknown-linux-gnueabi CC=$(CROSS_COMPILE)-gcc)

$(LIBMNL_DIR)/src/.libs/libmnl.a: $(LIBMNL_DIR)/Makefile
	make -C $(LIBMNL_DIR)

$(WIREGUARD_TAR):
	wget https://git.zx2c4.com/WireGuard/snapshot/$(WIREGUARD_TAR)

$(WIREGUARD_DIR)/src/Makefile: $(WIREGUARD_TAR)
	tar -xf $(WIREGUARD_TAR)

$(WG_TARGET): $(LIBMNL_DIR)/src/.libs/libmnl.a $(WIREGUARD_DIR)/src/Makefile
	CFLAGS=-I$(ROOT_DIR)/$(LIBMNL_DIR)/include LDFLAGS=-L$(ROOT_DIR)/$(LIBMNL_DIR)/src/.libs make -C $(WIREGUARD_DIR)/src/tools CC=$(CROSS_COMPILE)-gcc 

$(WG_QUICK_TARGET): $(WIREGUARD_DIR)/src/Makefile
	cp $(WIREGUARD_DIR)/src/tools/wg-quick/linux.bash $(WG_QUICK_TARGET)

$(WG_MODULE_TARGET):
	make -C $(WIREGUARD_DIR)/src module ARCH=arm KERNELDIR=$(KSRC) EXTRA_CFLAGS="-DCONFIG_SYNO_BACKPORT_ARM_CRYPTO=1"

install: all
	mkdir -p $(DESTDIR)/wireguard/
	install $(WG_TARGET) $(DESTDIR)/wireguard/
	install $(WG_QUICK_TARGET) $(DESTDIR)/wireguard/
	install $(WG_MODULE_TARGET) $(DESTDIR)/wireguard/

clean:
	rm -rf $(LIBMNL_TAR) $(LIBMNL_DIR) $(WIREGUARD_TAR) $(WIREGUARD_DIR)
