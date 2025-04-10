PAK_NAME := $(shell jq -r .label config.json)

ARCHITECTURES := arm arm64
PLATFORMS := miyoomini my282 rg35xxplus tg5040

MINUI_LIST_VERSION := 0.11.3
MINUI_PRESENTER_VERSION := 0.7.0
JQ_VERSION := 1.7.1
TAILSCALE_VERSION := 1.82.0

clean:
	rm -f bin/*/minui-list* || true
	rm -f bin/*/minui-presenter* || true
	rm -f bin/*/jq* || true
	rm -f bin/*/tailscale* || true
	rm -f bin/*/tailscaled* || true

build: $(foreach platform,$(PLATFORMS),bin/$(platform)/minui-list bin/$(platform)/minui-presenter) $(foreach arch,$(ARCHITECTURES),bin/$(arch)/jq bin/$(arch)/tailscale bin/$(arch)/tailscaled)

bin/%/minui-list:
	mkdir -p bin/$*
	curl -f -o bin/$*/minui-list -sSL https://github.com/josegonzalez/minui-list/releases/download/$(MINUI_LIST_VERSION)/minui-list-$*
	chmod +x bin/$*/minui-list

bin/%/minui-presenter:
	mkdir -p bin/$*
	curl -f -o bin/$*/minui-presenter -sSL https://github.com/josegonzalez/minui-presenter/releases/download/$(MINUI_PRESENTER_VERSION)/minui-presenter-$*
	chmod +x bin/$*/minui-presenter

bin/arm/jq:
	mkdir -p bin/arm
	curl -f -o bin/arm/jq -sSL https://github.com/jqlang/jq/releases/download/jq-$(JQ_VERSION)/jq-linux-armhf
	chmod +x bin/arm/jq
	curl -sSL -o bin/arm/jq.LICENSE "https://github.com/jqlang/jq/raw/refs/heads/master/COPYING"

bin/arm64/jq:
	mkdir -p bin/arm64
	curl -f -o bin/arm64/jq -sSL https://github.com/jqlang/jq/releases/download/jq-$(JQ_VERSION)/jq-linux-arm64
	chmod +x bin/arm64/jq
	curl -sSL -o bin/arm64/jq.LICENSE "https://github.com/jqlang/jq/raw/refs/heads/master/COPYING"

bin/%/tailscale:
	mkdir -p bin/$*
	curl -f -o bin/$*/tailscale.tar.gz -sSL https://pkgs.tailscale.com/stable/tailscale_$(TAILSCALE_VERSION)_$*.tgz
	mkdir -p bin/$*/tailscale_$*
	tar -xzf bin/$*/tailscale.tar.gz --strip-components=1 -C bin/$*/tailscale_$*
	mv bin/$*/tailscale_$*/tailscale bin/$*/tailscale
	rm -rf bin/$*/tailscale_$*
	rm -f bin/$*/tailscale.tar.gz
	chmod +x bin/$*/tailscale
	curl -sSL -o bin/$*/tailscale.LICENSE "https://github.com/tailscale/tailscale/raw/refs/heads/main/LICENSE"

bin/%/tailscaled:
	mkdir -p bin/$*
	curl -f -o bin/$*/tailscale.tar.gz -sSL https://pkgs.tailscale.com/stable/tailscale_$(TAILSCALE_VERSION)_$*.tgz
	mkdir -p bin/$*/tailscale_$*
	tar -xzf bin/$*/tailscale.tar.gz --strip-components=1 -C bin/$*/tailscale_$*
	mv bin/$*/tailscale_$*/tailscaled bin/$*/tailscaled
	rm -rf bin/$*/tailscale_$*
	rm -f bin/$*/tailscale.tar.gz
	chmod +x bin/$*/tailscaled
	curl -sSL -o bin/$*/tailscaled.LICENSE "https://github.com/tailscale/tailscale/raw/refs/heads/main/LICENSE"

release: build
	mkdir -p dist
	git archive --format=zip --output "dist/$(PAK_NAME).pak.zip" HEAD
	while IFS= read -r file; do zip -r "dist/$(PAK_NAME).pak.zip" "$$file"; done < .gitarchiveinclude
	ls -lah dist