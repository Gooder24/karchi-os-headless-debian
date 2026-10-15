# KarchiOS Headless (Debian) — everything runs unprivileged; root exists only inside the sandbox and the QEMU guests.
CACHE := $(HOME)/.cache/karchi-os-headless-debian
VM := python3 -B tools/vm.py

.PHONY: help check parts iso vm-test usb clean
help:
	@grep -E '^[a-z0-9-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*## /\t/' | expand -t 12

check: parts ## static checks and self-tests on the host, also of the parts (seconds)
	for f in iso/questions iso/late pkg/preinst pkg/postinst pkg/postrm; do sh -n $$f || exit 1; done
	for f in tools/*.sh tests/*.sh pkg/root/usr/bin/karchi-doctor pkg/root/usr/lib/karchi/* pkg/root/etc/profile.d/*; do bash -n $$f || exit 1; done
	python3 -c 'import ast, sys; [ast.parse(open(f).read(), f) for f in sys.argv[1:]]' tools/vm.py
	bash pkg/root/usr/lib/karchi/post-install --self-test
	sh iso/questions --self-test
	@unreadable=$$(find pkg/root ! -type l ! -perm -o=r); test -z "$$unreadable" || { echo "installed as-is, so users could not read: $$unreadable"; exit 1; }
	for part in parts/*/; do $(MAKE) --no-print-directory -C $$part check || exit 1; done

parts: # laptop-server and reboot-when-idle are git submodules: fetched when missing
	@test -e parts/laptop-server/Makefile -a -e parts/reboot-when-idle/Makefile || git submodule update --init

iso: check ## build the ISO into ~/.cache/karchi-os-headless-debian/out (first run downloads about 0.9 GB)
	tools/sandbox.sh /repo/tools/build-iso.sh
	tools/sandbox.sh /repo/tests/check-medium.sh

vm-test: ## install the newest ISO into a fresh VM without network, boot it twice with a power cut between, check it
	$(VM) test

usb: ## copy the newest ISO next to the others on a Ventoy stick, nothing is erased: make usb DIR=/run/media/$$USER/Ventoy/ISO
	@test -d "$(DIR)" || { echo 'usage: make usb DIR=<the folder with ISO files on a mounted Ventoy stick>'; exit 1; }
	iso=$$(ls -t $(CACHE)/out/*.iso | head -1) && cp -v "$$iso" "$(DIR)/" && sync && cmp "$$iso" "$(DIR)/$${iso##*/}" && echo 'copied and read back the same'

clean: ## remove build leftovers and test disks (the ISOs and the downloads stay)
	rm -rf $(CACHE)/build $(CACHE)/vm
