.PHONY: build run clean

build:
	bash scripts/build.sh

run: build
	open build/DoorSound.app

clean:
	rm -rf build
