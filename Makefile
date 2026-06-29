PROJECT   := DiskSweep.xcodeproj
SCHEME    := DiskSweep
APP       := DiskSweep.app
CONFIG    := Release
DEST      := platform=macOS
BUILD_DIR := build
DIST_DIR  := dist
ZIP       := $(DIST_DIR)/DiskSweep.zip

.PHONY: help generate build run test release clean

help: ## Muestra esta ayuda
	@echo "DiskSweep — comandos disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

generate: ## Genera DiskSweep.xcodeproj desde project.yml (con XcodeGen)
	xcodegen generate

build: generate ## Compila la app en modo Release
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-destination '$(DEST)' -derivedDataPath $(BUILD_DIR) build

run: generate ## Compila (Debug) y abre la app
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination '$(DEST)' -derivedDataPath $(BUILD_DIR) build
	open "$(BUILD_DIR)/Build/Products/Debug/$(APP)"

test: generate ## Ejecuta los tests unitarios
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' test

release: build ## Genera un binario distribuible (dist/DiskSweep.zip)
	@mkdir -p $(DIST_DIR)
	@rm -f $(ZIP)
	ditto -c -k --keepParent \
		"$(BUILD_DIR)/Build/Products/$(CONFIG)/$(APP)" "$(ZIP)"
	@echo "Binario listo: $(ZIP)"

clean: ## Borra artefactos de build, dist y el proyecto generado
	rm -rf $(BUILD_DIR) $(DIST_DIR) $(PROJECT)
