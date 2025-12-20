#!/bin/bash
# Build script to create a distributable macOS app bundle

set -e

APP_NAME="Futureport82Fixer"
SCRIPT_NAME="find-bottles-gui.py"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR="build"
DIST_DIR="dist"

echo "Building ${APP_NAME}..."

# Check if PyQt6 is installed
if ! python3 -c "import PyQt6" 2>/dev/null; then
    echo "PyQt6 not found. Installing..."
    if ! python3 -m pip install --user PyQt6 2>/dev/null; then
        echo "Trying with --break-system-packages flag..."
        python3 -m pip install --break-system-packages PyQt6
    fi
fi

# Check if PyInstaller is installed
PYINSTALLER_CMD=""
if command -v pyinstaller &> /dev/null; then
    PYINSTALLER_CMD="pyinstaller"
elif python3 -c "import PyInstaller" 2>/dev/null; then
    PYINSTALLER_CMD="python3 -m PyInstaller"
else
    echo "PyInstaller not found. Installing..."
    # Try with --user flag first, fall back to --break-system-packages if needed
    if ! python3 -m pip install --user pyinstaller 2>/dev/null; then
        echo "Trying with --break-system-packages flag..."
        python3 -m pip install --break-system-packages pyinstaller
    fi
    # Check again after installation
    if command -v pyinstaller &> /dev/null; then
        PYINSTALLER_CMD="pyinstaller"
    elif python3 -c "import PyInstaller" 2>/dev/null; then
        PYINSTALLER_CMD="python3 -m PyInstaller"
    else
        # Add user bin directory to PATH
        PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
        export PATH="$HOME/Library/Python/${PYTHON_VERSION}/bin:$PATH"
        if command -v pyinstaller &> /dev/null; then
            PYINSTALLER_CMD="pyinstaller"
        else
            PYINSTALLER_CMD="python3 -m PyInstaller"
        fi
    fi
fi

echo "Using PyInstaller command: ${PYINSTALLER_CMD}"

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf "${BUILD_DIR}" "${DIST_DIR}" "${APP_BUNDLE}"

# Create the app bundle with PyInstaller
echo "Creating app bundle..."
${PYINSTALLER_CMD} \
    --name="${APP_NAME}" \
    --windowed \
    --onedir \
    --add-data "system32:system32" \
    --add-data "syswow64:syswow64" \
    --add-data "mf-fix-cx.sh:." \
    --add-data "mf.reg:." \
    --add-data "wmf.reg:." \
    --add-data "mfplat.dll:." \
    --osx-bundle-identifier="com.futureport82.fixer" \
    --target-arch arm64 \
    "${SCRIPT_NAME}"

# Move the app bundle to the root directory
if [ -d "${DIST_DIR}/${APP_BUNDLE}" ]; then
    mv "${DIST_DIR}/${APP_BUNDLE}" .
    echo "App bundle created: ${APP_BUNDLE}"
    echo ""
    echo "To distribute:"
    echo "  1. Test the app: open ${APP_BUNDLE}"
    echo "  2. Create a DMG (optional):"
    echo "     hdiutil create -volname \"${APP_NAME}\" -srcfolder \"${APP_BUNDLE}\" -ov -format UDZO \"${APP_NAME}.dmg\""
else
    echo "Error: App bundle not found in ${DIST_DIR}/"
    exit 1
fi

