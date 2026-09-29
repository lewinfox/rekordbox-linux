IMAGE := rekordbox-wine

.PHONY: container install

## Build the Docker image (patched wine-staging + rekordbox-wine launcher)
container:
	docker build -t $(IMAGE) .

## Interactive setup: image, host config, rekordbox, desktop launcher
install:
	./install.sh
