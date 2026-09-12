PROJECT   := DiskSweep.xcodeproj
SCHEME    := DiskSweep
APP       := DiskSweep.app
CONFIG    := Release
DEST      := platform=macOS
BUILD_DIR := build
DIST_DIR  := dist
ZIP       := $(DIST_DIR)/DiskSweep.zip

.PHONY: help generate build run test release clean

help: ## Show this help
	@echo "DiskSweep — available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

generate: ## Generate DiskSweep.xcodeproj from project.yml with XcodeGen
	xcodegen generate

build: generate ## Build the app in Release mode
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-destination '$(DEST)' -derivedDataPath $(BUILD_DIR) build

run: generate ## Build the app in Debug mode and open it
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination '$(DEST)' -derivedDataPath $(BUILD_DIR) build
	open "$(BUILD_DIR)/Build/Products/Debug/$(APP)"

test: generate ## Run the unit tests
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' test

release: build ## Create a distributable archive (dist/DiskSweep.zip)
	@mkdir -p $(DIST_DIR)
	@rm -f $(ZIP)
	ditto -c -k --keepParent \
		"$(BUILD_DIR)/Build/Products/$(CONFIG)/$(APP)" "$(ZIP)"
	@echo "Archive ready: $(ZIP)"

clean: ## Remove build artifacts, distributions, and the generated project
	rm -rf $(BUILD_DIR) $(DIST_DIR) $(PROJECT)
