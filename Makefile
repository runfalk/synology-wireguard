APPLY_MEMNEQ_PATCH ?= 0
APPLY_SPINLOCK_PATCH ?= 0

LIBMNL_TAR := libmnl-$(LIBMNL_VERSION).tar.bz2
LIBMNL_DIR := libmnl-$(LIBMNL_VERSION)

WIREGUARD_TAR := wireguard-linux-compat-$(WIREGUARD_VERSION).tar.xz
WIREGUARD_DIR := wireguard-linux-compat-$(WIREGUARD_VERSION)

WIREGUARD_TOOLS_TAR := wireguard-tools-$(WIREGUARD_TOOLS_VERSION).tar.xz
WIREGUARD_TOOLS_DIR := wireguard-tools-$(WIREGUARD_TOOLS_VERSION)

WG_TARGET := $(WIREGUARD_TOOLS_DIR)/src/wg
WG_QUICK_TARGET := $(WIREGUARD_TOOLS_DIR)/wg-quick
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
	wget https://git.zx2c4.com/wireguard-linux-compat/snapshot/$(WIREGUARD_TAR)

$(WIREGUARD_TOOLS_TAR):
	wget https://git.zx2c4.com/wireguard-tools/snapshot/$(WIREGUARD_TOOLS_TAR)

# Unpack WireGuard source tarball. Patch the wireguard interface verification
# due to the unavailability of rtnl_link_ops structure in the network device on DSM 7.0.
# If required, patch the compatibility layer to always use memneq implementation
# and patch the spinlock implementation.
$(WIREGUARD_DIR)/src/Makefile: $(WIREGUARD_TAR)
	tar -xf $(WIREGUARD_TAR)
	patch $(WIREGUARD_DIR)/src/netlink.c $(ROOT_DIR)/patch/netlink.patch
	patch $(WIREGUARD_DIR)/src/peerlookup.c $(ROOT_DIR)/patch/peerlookup.patch
	patch $(WIREGUARD_DIR)/src/compat/compat.h $(ROOT_DIR)/patch/wireguard-linux-compat.patch
ifeq ($(APPLY_MEMNEQ_PATCH), 1)
	patch $(WIREGUARD_DIR)/src/compat/Kbuild.include $(ROOT_DIR)/patch/memneq.patch
endif
ifeq ($(APPLY_SPINLOCK_PATCH), 1)
	patch $(WIREGUARD_DIR)/src/ratelimiter.c $(ROOT_DIR)/patch/spinlock.patch
endif

$(WIREGUARD_TOOLS_DIR)/src/Makefile: $(WIREGUARD_TOOLS_TAR)
	tar -xf $(WIREGUARD_TOOLS_TAR)

# Build the wg command line tool
$(WG_TARGET): $(LIBMNL_DIR)/src/.libs/libmnl.a $(WIREGUARD_TOOLS_DIR)/src/Makefile
	CFLAGS=-I$(ROOT_DIR)/$(LIBMNL_DIR)/include LDFLAGS=-L$(ROOT_DIR)/$(LIBMNL_DIR)/src/.libs make -C $(WIREGUARD_TOOLS_DIR)/src CC=$(GCC)

# Choose the correct wg-quick implementation
$(WG_QUICK_TARGET): $(WIREGUARD_TOOLS_DIR)/src/Makefile
	cp $(WIREGUARD_TOOLS_DIR)/src/wg-quick/linux.bash $(WG_QUICK_TARGET)

# Build wireguard.ko kernel module
$(WG_MODULE_TARGET): $(WIREGUARD_DIR)/src/Makefile
	make -C $(WIREGUARD_DIR)/src module ARCH=$(ARCH) KERNELDIR=$(KSRC)

install: all
	mkdir -p $(DESTDIR)/wireguard/
	install $(WG_TARGET) $(DESTDIR)/wireguard/
	install $(WG_QUICK_TARGET) $(DESTDIR)/wireguard/
	install $(WG_MODULE_TARGET) $(DESTDIR)/wireguard/
	install $(ROOT_DIR)/wireguard/wg-autostart $(DESTDIR)/wireguard/

clean:
	rm -rf $(LIBMNL_TAR) $(LIBMNL_DIR) $(WIREGUARD_TAR) $(WIREGUARD_DIR) $(WIREGUARD_TOOLS_TAR) $(WIREGUARD_TOOLS_DIR)
