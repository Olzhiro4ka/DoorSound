.PHONY: build dmg run clean

build:
	bash scripts/build.sh

dmg:
	bash scripts/build-dmg.sh

run: build
	open build/DoorSound.app

clean:
	rm -rf build
