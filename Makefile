.PHONY: build run clean format lint test build-app install uninstall help

help:
	@echo "vos - macOS Menu Bar Transcription App"
	@echo ""
	@echo "Available commands:"
	@echo "  make build       - Build debug binary"
	@echo "  make run         - Build and run from source"
	@echo "  make test        - Run unit tests"
	@echo "  make build-app   - Build vos.app bundle"
	@echo "  make install     - Build and install to ~/Applications"
	@echo "  make uninstall   - Remove vos.app from Applications"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make format      - Format Swift code"
	@echo "  make lint        - Lint Swift code"
	@echo "  make help        - Show this help message"

build:
	@echo "Building vos..."
	@swift build

run: build
	@echo "Running vos..."
	@./.build/debug/vos

build-app:
	@./scripts/build-app.sh

install: build-app
	@echo "Installing vos.app to ~/Applications..."
	@mkdir -p ~/Applications
	@rm -rf ~/Applications/vos.app
	@cp -r vos.app ~/Applications/
	@echo "✅ vos installed to ~/Applications/vos.app"
	@echo ""
	@echo "Launch vos from:"
	@echo "  • Spotlight (Cmd+Space, type 'vos')"
	@echo "  • Launchpad"
	@echo "  • Finder → Applications"

uninstall:
	@echo "Uninstalling vos..."
	@rm -rf ~/Applications/vos.app
	@rm -rf /Applications/vos.app
	@echo "✅ vos uninstalled"

clean:
	@echo "Cleaning build artifacts..."
	@swift package clean
	@rm -rf .build vos.app

format:
	@echo "Formatting Swift code..."
	@if command -v swift-format >/dev/null 2>&1; then \
		swift-format -i -r vos/; \
		echo "Code formatted successfully"; \
	else \
		echo "swift-format not installed. Install with: brew install swift-format"; \
	fi

lint:
	@echo "Linting Swift code..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint vos/; \
	else \
		echo "swiftlint not installed. Install with: brew install swiftlint"; \
	fi

test:
	@echo "Running unit tests..."
	@swift test
