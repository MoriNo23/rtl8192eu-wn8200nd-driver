# Forwarding Makefile — delegates all targets to driver/
# This allows DKMS (which expects Makefile at source root) and
# manual builds to work transparently.

MAKEFLAGS += --no-print-directory

.DEFAULT:
	$(MAKE) -C driver $@

%:
	$(MAKE) -C driver $@

all modules modules_install install clean:
	$(MAKE) -C driver $@

.PHONY: all modules modules_install install clean
