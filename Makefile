APP_NAME = FP82Fixer
BUNDLE_ID = com.fp82fixer.mac
PLISTBUDDY = /usr/libexec/PlistBuddy
BINARY = .build/release/$(APP_NAME)
BUNDLE_DIR = build/$(APP_NAME).app

.PHONY: build run release bundle dist clean version bump-patch bump-minor bump-major tag sign notarize release-signed verify-signature

build:
	swift build

run: build
	swift run

release:
	swift build -c release

bundle: release
	@echo "Creating app bundle..."
	@rm -rf $(BUNDLE_DIR)
	@mkdir -p $(BUNDLE_DIR)/Contents/MacOS
	@mkdir -p $(BUNDLE_DIR)/Contents/Resources
	@cp $(BINARY) $(BUNDLE_DIR)/Contents/MacOS/
	@# Copy SPM resource bundle to Resources (Bundle.module finds it via Bundle.main.resourceURL)
	@cp -R .build/release/$(APP_NAME)_$(APP_NAME).bundle $(BUNDLE_DIR)/Contents/Resources/ 2>/dev/null || true
	@cp Resources/Info.plist $(BUNDLE_DIR)/Contents/
	@# Update version in bundle
	@VERSION=$$($(PLISTBUDDY) -c "Print CFBundleShortVersionString" Resources/Info.plist) && \
		$(PLISTBUDDY) -c "Set :CFBundleShortVersionString $$VERSION" $(BUNDLE_DIR)/Contents/Info.plist && \
		$(PLISTBUDDY) -c "Set :CFBundleVersion $$VERSION" $(BUNDLE_DIR)/Contents/Info.plist
	@# Copy icon if present
	@cp Resources/AppIcon.icns $(BUNDLE_DIR)/Contents/Resources/ 2>/dev/null || true
	@# Ad-hoc sign
	@codesign --force --sign - $(BUNDLE_DIR)
	@echo "Bundle created: $(BUNDLE_DIR)"

dist: bundle
	@echo "Creating distribution zip..."
	@cd build && zip -r $(APP_NAME).zip $(APP_NAME).app
	@echo "Distribution: build/$(APP_NAME).zip"

clean:
	swift package clean
	rm -rf build/ .build/

version:
	@$(PLISTBUDDY) -c "Print CFBundleShortVersionString" Resources/Info.plist

bump-patch:
	@CURRENT=$$($(PLISTBUDDY) -c "Print CFBundleShortVersionString" Resources/Info.plist) && \
		MAJOR=$$(echo $$CURRENT | awk -F. '{print $$1}') && \
		MINOR=$$(echo $$CURRENT | awk -F. '{print $$2}') && \
		PATCH=$$(echo $$CURRENT | awk -F. '{print $$3}') && \
		NEW="$$MAJOR.$$MINOR.$$((PATCH + 1))" && \
		$(PLISTBUDDY) -c "Set :CFBundleShortVersionString $$NEW" Resources/Info.plist && \
		$(PLISTBUDDY) -c "Set :CFBundleVersion $$NEW" Resources/Info.plist && \
		echo "Version bumped: $$CURRENT -> $$NEW"

bump-minor:
	@CURRENT=$$($(PLISTBUDDY) -c "Print CFBundleShortVersionString" Resources/Info.plist) && \
		MAJOR=$$(echo $$CURRENT | awk -F. '{print $$1}') && \
		MINOR=$$(echo $$CURRENT | awk -F. '{print $$2}') && \
		NEW="$$MAJOR.$$((MINOR + 1)).0" && \
		$(PLISTBUDDY) -c "Set :CFBundleShortVersionString $$NEW" Resources/Info.plist && \
		$(PLISTBUDDY) -c "Set :CFBundleVersion $$NEW" Resources/Info.plist && \
		echo "Version bumped: $$CURRENT -> $$NEW"

bump-major:
	@CURRENT=$$($(PLISTBUDDY) -c "Print CFBundleShortVersionString" Resources/Info.plist) && \
		MAJOR=$$(echo $$CURRENT | awk -F. '{print $$1}') && \
		NEW="$$((MAJOR + 1)).0.0" && \
		$(PLISTBUDDY) -c "Set :CFBundleShortVersionString $$NEW" Resources/Info.plist && \
		$(PLISTBUDDY) -c "Set :CFBundleVersion $$NEW" Resources/Info.plist && \
		echo "Version bumped: $$CURRENT -> $$NEW"

tag:
	@VERSION=$$($(PLISTBUDDY) -c "Print CFBundleShortVersionString" Resources/Info.plist) && \
		git add -A && \
		git commit -m "Release v$$VERSION" && \
		git tag "v$$VERSION" && \
		git push && git push --tags && \
		echo "Tagged and pushed v$$VERSION"

sign: bundle
	@if [ -z "$(SIGNING_IDENTITY)" ]; then echo "Set SIGNING_IDENTITY env var"; exit 1; fi
	codesign --force --deep --options runtime \
		--entitlements Resources/FP82Fixer.entitlements \
		--sign "$(SIGNING_IDENTITY)" \
		--timestamp \
		$(BUNDLE_DIR)
	@echo "Signed $(BUNDLE_DIR)"

notarize: sign
	@if [ -z "$(APPLE_ID)" ]; then echo "Set APPLE_ID env var"; exit 1; fi
	@if [ -z "$(TEAM_ID)" ]; then echo "Set TEAM_ID env var"; exit 1; fi
	@if [ -z "$(APP_PASSWORD)" ]; then echo "Set APP_PASSWORD env var"; exit 1; fi
	@cd build && zip -r $(APP_NAME)-notarize.zip $(APP_NAME).app
	@SUBMISSION_ID=$$(xcrun notarytool submit build/$(APP_NAME)-notarize.zip \
		--apple-id "$(APPLE_ID)" \
		--team-id "$(TEAM_ID)" \
		--password "$(APP_PASSWORD)" | sed -n 's/^  id: //p' | head -1); \
	if [ -z "$$SUBMISSION_ID" ]; then \
		echo "Failed to read notarization submission ID."; \
		exit 1; \
	fi; \
	echo "Notarization submission ID: $$SUBMISSION_ID"; \
	ATTEMPTS=0; \
	while true; do \
		STATUS=$$(xcrun notarytool info "$$SUBMISSION_ID" \
			--apple-id "$(APPLE_ID)" \
			--team-id "$(TEAM_ID)" \
			--password "$(APP_PASSWORD)" | sed -n 's/^ *status: //p' | head -1); \
		echo "Current status: $$STATUS"; \
		if [ "$$STATUS" = "Accepted" ]; then \
			break; \
		fi; \
		if [ "$$STATUS" = "Invalid" ] || [ "$$STATUS" = "Rejected" ]; then \
			echo "Notarization failed. Retrieving log..."; \
			xcrun notarytool log "$$SUBMISSION_ID" \
				--apple-id "$(APPLE_ID)" \
				--team-id "$(TEAM_ID)" \
				--password "$(APP_PASSWORD)"; \
			exit 1; \
		fi; \
		ATTEMPTS=$$((ATTEMPTS + 1)); \
		if [ "$$ATTEMPTS" -ge 240 ]; then \
			echo "Timed out waiting for notarization after 60 minutes."; \
			exit 1; \
		fi; \
		sleep 15; \
	done
	xcrun stapler staple $(BUNDLE_DIR)
	@cd build && rm -f $(APP_NAME).zip $(APP_NAME)-notarize.zip && \
		zip -r $(APP_NAME).zip $(APP_NAME).app
	@echo "Notarized and stapled: build/$(APP_NAME).zip"

release-signed: notarize
	@echo "Signed, notarized distribution ready: build/$(APP_NAME).zip"

verify-signature:
	codesign --verify --deep --strict --verbose=2 $(BUNDLE_DIR)
	spctl --assess --type execute --verbose $(BUNDLE_DIR)
