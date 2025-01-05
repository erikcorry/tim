.PHONY: all
all: build

.PHONY: build
build: rebuild-cmake install-pkgs
	(cd build && ninja build)

.PHONY: test
test: rebuild-cmake install-pkgs
	 (cd build && ninja check)

.PHONY: build/CMakeCache.txt
build/CMakeCache.txt:
	$(MAKE) rebuild-cmake

.PHONY: install-pkgs
install-pkgs: rebuild-cmake
	(cd build && ninja download_packages)

.PHONY: rebuild-cmake
rebuild-cmake:
	mkdir -p build
	(cd build && cmake .. -G Ninja)
