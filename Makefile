WIREGUARD_VERSION ?= 0.0.20190227
LIBMNL_VERSION ?= 1.0.4
HAS_MEMNEQ ?= 0

LIBMNL_TAR := libmnl-$(LIBMNL_VERSION).tar.bz2
LIBMNL_DIR := libmnl-$(LIBMNL_VERSION)

WIREGUARD_TAR := WireGuard-$(WIREGUARD_VERSION).tar.xz
WIREGUARD_DIR := WireGuard-$(WIREGUARD_VERSION)

WG_TARGET := $(WIREGUARD_DIR)/src/tools/wg
WG_QUICK_TARGET := $(WIREGUARD_DIR)/wg-quick
WG_MODULE_TARGET := $(WIREGUARD_DIR)/src/wireguard.ko

GCC := $(CROSS_COMPILE)gcc
TARGET_TRIPLE := $(shell echo $(CROSS_COMPILE)|cut -f4 -d/ -)

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

all: $(WG_TARGET) $(WG_QUICK_TARGET) $(WG_MODULE_TARGET)

# Download libmnl source tarball
$(LIBMNL_TAR):
	wget https://netfilter.org/projects/libmnl/files/$(LIBMNL_TAR)

# Prepare libmnl for building
$(LIBMNL_DIR)/Makefile: $(LIBMNL_TAR)
	tar -xf $(LIBMNL_TAR)
	(cd $(LIBMNL_DIR) && ./configure --host=$(shell gcc -dumpmachine) --enable-static --target=$(TARGET_TRIPLE) CC=$(GCC))

# Compile libmnl static lib
$(LIBMNL_DIR)/src/.libs/libmnl.a: $(LIBMNL_DIR)/Makefile
	make -C $(LIBMNL_DIR)

# Download WireGuard source tarball
$(WIREGUARD_TAR):
	wget https://git.zx2c4.com/WireGuard/snapshot/$(WIREGUARD_TAR)

# Unpack WireGuard source tarball and patch the compatibility layer to always
# use memneq implementation as it doesn't appear to be included on the D218j.
$(WIREGUARD_DIR)/src/Makefile: $(WIREGUARD_TAR)
	tar -xf $(WIREGUARD_TAR)
ifeq ($(HAS_MEMNEQ), 0)
	patch $(WIREGUARD_DIR)/src/compat/Kbuild.include $(ROOT_DIR)/memneq.patch
endif

# Build the wg command line tool
$(WG_TARGET): $(LIBMNL_DIR)/src/.libs/libmnl.a $(WIREGUARD_DIR)/src/Makefile
	CFLAGS=-I$(ROOT_DIR)/$(LIBMNL_DIR)/include LDFLAGS=-L$(ROOT_DIR)/$(LIBMNL_DIR)/src/.libs make -C $(WIREGUARD_DIR)/src/tools CC=$(GCC)

# Choose the correct wg-quick implementation
$(WG_QUICK_TARGET): $(WIREGUARD_DIR)/src/Makefile
	cp $(WIREGUARD_DIR)/src/tools/wg-quick/linux.bash $(WG_QUICK_TARGET)

# Build wireguard.ko kernel module
$(WG_MODULE_TARGET):
	make -C $(WIREGUARD_DIR)/src module ARCH=$(ARCH) KERNELDIR=$(KSRC)

install: all
	mkdir -p $(DESTDIR)/wireguard/
	install $(WG_TARGET) $(DESTDIR)/wireguard/
	install $(WG_QUICK_TARGET) $(DESTDIR)/wireguard/
	install $(WG_MODULE_TARGET) $(DESTDIR)/wireguard/

clean:
	rm -rf $(LIBMNL_TAR) $(LIBMNL_DIR) $(WIREGUARD_TAR) $(WIREGUARD_DIR)
