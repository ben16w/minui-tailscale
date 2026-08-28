PAK_NAME := $(shell jq -r .name pak.json)

ARCHITECTURES := arm arm64
PLATFORMS := h700 m17 magicmini miyoomini my282 my355 rg35xx rg35xxplus rgb30 tg5040 tg5050 trimuismart zero28

MINUI_LIST_VERSION := 0.15.0
MINUI_PRESENTER_VERSION := 0.13.0
JQ_VERSION := 1.8.2
TAILSCALE_VERSION := 1.102.3

clean:
	rm -f bin/*/minui-list* || true
	rm -f bin/*/minui-presenter* || true
	rm -f bin/*/jq* || true
	rm -f bin/*/tailscale* || true
	rm -f bin/*/tailscaled* || true
	rm -f ca-certificates.crt || true

bump-version:
	jq '.version = "$(RELEASE_VERSION)"' pak.json > pak.json.tmp
	mv pak.json.tmp pak.json

build: $(foreach platform,$(PLATFORMS),bin/$(platform)/minui-list bin/$(platform)/minui-presenter) $(foreach arch,$(ARCHITECTURES),bin/$(arch)/jq bin/$(arch)/tailscale bin/$(arch)/tailscaled) ca-certificates.crt
	@echo "Build complete"

bin/%/minui-list:
	mkdir -p bin/$*
	curl -f -o bin/$*/minui-list -sSL https://github.com/josegonzalez/minui-list/releases/download/$(MINUI_LIST_VERSION)/minui-list-$*
	chmod +x bin/$*/minui-list

bin/%/minui-presenter:
	mkdir -p bin/$*
	curl -f -o bin/$*/minui-presenter -sSL https://github.com/josegonzalez/minui-presenter/releases/download/$(MINUI_PRESENTER_VERSION)/minui-presenter-$*
	chmod +x bin/$*/minui-presenter

bin/h700/minui-list:
	mkdir -p bin/h700
	curl -f -o bin/h700/minui-list -sSL https://github.com/josegonzalez/minui-list/releases/download/$(MINUI_LIST_VERSION)/minui-list-h700-nextui
	chmod +x bin/h700/minui-list

bin/h700/minui-presenter:
	mkdir -p bin/h700
	curl -f -o bin/h700/minui-presenter -sSL https://github.com/josegonzalez/minui-presenter/releases/download/$(MINUI_PRESENTER_VERSION)/minui-presenter-h700-nextui
	chmod +x bin/h700/minui-presenter

bin/tg5050/minui-list:
	mkdir -p bin/tg5050
	curl -f -o bin/tg5050/minui-list -sSL https://github.com/josegonzalez/minui-list/releases/download/$(MINUI_LIST_VERSION)/minui-list-tg5050-nextui
	chmod +x bin/tg5050/minui-list

bin/tg5050/minui-presenter:
	mkdir -p bin/tg5050
	curl -f -o bin/tg5050/minui-presenter -sSL https://github.com/josegonzalez/minui-presenter/releases/download/$(MINUI_PRESENTER_VERSION)/minui-presenter-tg5050-nextui
	chmod +x bin/tg5050/minui-presenter

bin/arm/jq:
	mkdir -p bin/arm
	curl -f -o bin/arm/jq -sSL https://github.com/jqlang/jq/releases/download/jq-$(JQ_VERSION)/jq-linux-armhf
	chmod +x bin/arm/jq
	curl -sSL -o bin/arm/jq.LICENSE "https://raw.githubusercontent.com/jqlang/jq/refs/tags/jq-$(JQ_VERSION)/COPYING"

bin/arm64/jq:
	mkdir -p bin/arm64
	curl -f -o bin/arm64/jq -sSL https://github.com/jqlang/jq/releases/download/jq-$(JQ_VERSION)/jq-linux-arm64
	chmod +x bin/arm64/jq
	curl -sSL -o bin/arm64/jq.LICENSE "https://raw.githubusercontent.com/jqlang/jq/refs/tags/jq-$(JQ_VERSION)/COPYING"

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

ca-certificates.crt:
	curl -f -o ca-certificates.crt -sSL https://curl.se/ca/cacert.pem

release: build
	mkdir -p dist
	git archive --format=zip --output "dist/$(PAK_NAME).pak.zip" HEAD
	while IFS= read -r file; do zip -r "dist/$(PAK_NAME).pak.zip" "$$file"; done < .gitarchiveinclude
	ls -lah dist