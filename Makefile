.PHONY: build run clean format format-check lint check test build-app install uninstall dev all help

help:
	@echo "vox - macOS Menu Bar Transcription App"
	@echo ""
	@echo "Available commands:"
	@echo "  make build        - Build debug binary"
	@echo "  make run          - Build and run from source"
	@echo "  make dev          - Build and run with verbose output"
	@echo "  make test         - Run unit tests"
	@echo "  make build-app    - Build vox.app bundle"
	@echo "  make install      - Build and install to ~/Applications"
	@echo "  make uninstall    - Remove vox.app from Applications"
	@echo "  make clean        - Clean build artifacts"
	@echo "  make format       - Format Swift code"
	@echo "  make format-check - Check formatting without modifying"
	@echo "  make lint         - Lint Swift code"
	@echo "  make check        - Run lint + format-check"
	@echo "  make all          - Full pipeline: check, build, test"
	@echo "  make help         - Show this help message"

build:
	@echo "Building vox..."
	@swift build

run: build
	@echo "Running vox..."
	@./.build/debug/vox

build-app:
	@./scripts/build-app.sh

install: build-app
	@echo "Installing vox.app to ~/Applications..."
	@mkdir -p ~/Applications
	@rm -rf ~/Applications/vox.app
	@cp -r vox.app ~/Applications/
	@echo "✅ vox installed to ~/Applications/vox.app"
	@echo ""
	@echo "Launch vox from:"
	@echo "  • Spotlight (Cmd+Space, type 'vox')"
	@echo "  • Launchpad"
	@echo "  • Finder → Applications"

uninstall:
	@echo "Uninstalling vox..."
	@rm -rf ~/Applications/vox.app
	@rm -rf /Applications/vox.app
	@echo "✅ vox uninstalled"

clean:
	@echo "Cleaning build artifacts..."
	@swift package clean
	@rm -rf .build vox.app

format:
	@echo "Formatting Swift code..."
	@if command -v swift-format >/dev/null 2>&1; then \
		swift-format -i -r vox/; \
		echo "Code formatted successfully"; \
	else \
		echo "swift-format not installed. Install with: brew install swift-format"; \
	fi

lint:
	@echo "Linting Swift code..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint vox/; \
	else \
		echo "swiftlint not installed. Install with: brew install swiftlint"; \
	fi

test:
	@echo "Running unit tests..."
	@swift test

dev:
	@echo "Building vox (verbose)..."
	@swift build 2>&1
	@echo ""
	@echo "Running vox..."
	@./.build/debug/vox

format-check:
	@echo "Checking Swift formatting..."
	@if command -v swift-format >/dev/null 2>&1; then \
		if swift-format lint -r vox/ 2>&1 | grep -q "warning\|error"; then \
			swift-format lint -r vox/; \
			exit 1; \
		else \
			echo "✓ Formatting looks good"; \
		fi \
	else \
		echo "⚠ swift-format not installed. Install with: brew install swift-format"; \
	fi

check: lint format-check
	@echo ""
	@echo "✓ All checks passed"

all: check build test
	@echo ""
	@echo "✓ Full pipeline complete"
