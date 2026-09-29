IMAGE := rekordbox-wine

.PHONY: container install webview2

## Build the Docker image (patched wine-staging + rekordbox-wine launcher)
container:
	docker build -t $(IMAGE) .

## Interactive setup: image, host config, rekordbox, desktop launcher
install:
	./install.sh

## Install Microsoft Edge WebView2 into the prefix (needed for SoundCloud/Spotify logins)
webview2:
	./webview2.sh
