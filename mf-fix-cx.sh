#!/bin/bash

# Function to run sudo commands with GUI password prompt on macOS
function gui_sudo {
	# Always check for GUI_SUDO_PASSWORD first (when running from GUI app)
	if [[ -n "$GUI_SUDO_PASSWORD" ]]; then
		# Use password from environment variable with sudo -S (reads from stdin)
		echo "$GUI_SUDO_PASSWORD" | sudo -S "$@" 2>&1
		local exit_code=$?
		if [ $exit_code -ne 0 ]; then
			echo "Warning: sudo operation failed (exit code $exit_code)" >&2
			return $exit_code
		fi
	elif [[ -t 0 ]]; then
		# Running in terminal without GUI password, use regular sudo
		sudo "$@"
	else
		# Running in GUI but no password provided - skip sudo operation
		echo "Warning: Skipping sudo operation (no password provided). File may not be copied." >&2
		return 1
	fi
}

# Check Wine sanity # -- use system.reg to figure arch, search for "#arch=win32" or "#arch=win64"
function sanity {
	if [[ -z "$WPATH" ]]; then
		echo "Wine prefix path is not set"
		exit 3 # WINE_PREFIX not set
	fi
	if [[ ! -d "$WPATH/drive_c" ]]; then
		echo "Prefix path does not appear to be a valid prefix ( '$WPATH' )"
		exit 4 # "<WINE_PREFIX>/drive_c" directory does not exist
	fi
}

# Check the given exe path can make sense
function exe_santiy {
	if [[ -e "$1" ]]; then
		# Exists as a file or directory
		if [[ -d "$1" ]]; then
			# Is a directory
			E=true
			EPATH="$1"
		else
			# Is a file
			containing_dir="$(dirname "$(realpath "$1")")"
			if [[ -d "$containing_dir" ]]; then
				E=true
				EPATH="$containing_dir"
				echo "$containing_dir"
			else
				echo "Unknown error trying to understand executable path."
				exit 6
			fi
		fi
	else
		# Does not exist
		echo "Executable path does not exist"
		exit 5
	fi
}

# Help / Usage message
function print_help {
	echo "Usage: mf-fix-cx [OPTIONS] [PREFIX PATH]"
	echo "Options:"
	echo "    -v | --verbose : Enable verbose info messages"
	echo "    -n | --noconfirm : Skip confirmation before utilizing sudo to override the symbolic links Proton uses in its prefixes (if that is needed)"
	echo "    -e | --executable <PATH> : Path of the directory containing the executable of the game you are patching"
	echo "    -h | --help : Print this help message"
	echo ""
	echo "This script is modified to work with CrossOver bottles."
	echo ""
	echo "Executable path can either lead to the executable or its containing folder. This is used at the end of the script to copy mfplat.dll to the game's directory. If this option is omitted, you will need to copy the dll into the game's directory yourself."
	echo ""
	echo "<PREFIX WPATH> is the path of the CrossOver bottle (e.g. /Users/username/Library/Application Support/CrossOver/Bottles/BottleName)"
	echo ""
    echo "Usage example:"
    echo "./mf-fix-cx.sh -e \"/Users/username/Library/Application Support/CrossOver/Bottles/Steam/drive_c/Program Files (x86)/Directory/Game\" \"/Users/username/Library/Application Support/CrossOver/Bottles/BottleName\""
    echo ""
	echo "Exit codes:"
	echo "    0 : Success"
	echo "    1 : Unknown option"
	echo "    2 : Invalid path given"
	echo "    3 : Wine prefix path is not set"
	echo "    4 : Given path does not appear to be a valid Wine prefix"
	echo "    5 : Executable path does not exist"
	echo "    6 : Attempting to get the directory containing executable at provided path resulted in a file path or a non-existant directory"
	exit 0
}

# Copy dll files
function run_copies {
	cd "${mydir}/system32"
	arr=(*)
	for (( i=0; i<${#arr[@]}; i++ )); do
		if [[ -h "${WPATH}/drive_c/windows/system32/${arr[$i]}" ]]; then
			# Is a sym link
			echo "system32/${arr[$i]} is a sym link"
			if [[ -w "${WPATH}/drive_c/windows/system32/${arr[$i]}" ]]; then
				# Is writeable
				echo "system32/${arr[$i]} is normally writeable"
				rm "${WPATH}/drive_c/windows/system32/${arr[$i]}" && cp "${arr[$i]}" "${WPATH}/drive_c/windows/system32/"
			else
				# Is not writeable
				echo "system32/${arr[$i]} is not normally writeable, need to use sudo"
				if ! gui_sudo rm "${WPATH}/drive_c/windows/system32/${arr[$i]}" 2>&1; then
					echo "Warning: Failed to remove ${arr[$i]} with sudo, skipping..."
				else
					cp "${arr[$i]}" "${WPATH}/drive_c/windows/system32/"
				fi
			fi
		else
			# Is not a sym link
			echo "system32/${arr[$i]} is not a sym link"
			if [[ -w "${WPATH}/drive_c/windows/system32/${arr[$i]}" ]]; then
				# Is writeable
				echo "system32/${arr[$i]} is normally writeable"
				cp "${arr[$i]}" "${WPATH}/drive_c/windows/system32/"
			else
				# Is not writeable
				echo "system32/${arr[$i]} is not normally writeable, need to use sudo"
				if ! gui_sudo cp "${arr[$i]}" "${WPATH}/drive_c/windows/system32/" 2>&1; then
					echo "Warning: Failed to copy ${arr[$i]} with sudo, skipping..."
				fi
			fi
		fi
	done
	cd "${mydir}/syswow64"
	arr=(*)
	for (( i=0; i<${#arr[@]}; i++ )); do
		if [[ -h "${WPATH}/drive_c/windows/syswow64/${arr[$i]}" ]]; then
			# Is a sym link
			echo "syswow64/${arr[$i]} is a sym link"
			if [[ -w "${WPATH}/drive_c/windows/syswow64/${arr[$i]}" ]]; then
				# Is writeable
				echo "syswow64/${arr[$i]} is normally writeable"
				rm "${WPATH}/drive_c/windows/syswow64/${arr[$i]}" && cp "${arr[$i]}" "${WPATH}/drive_c/windows/syswow64/"
			else
				# Is not writeable
				echo "syswow64/${arr[$i]} is not normally writeable, need to use sudo"
				if ! gui_sudo rm "${WPATH}/drive_c/windows/syswow64/${arr[$i]}" 2>&1; then
					echo "Warning: Failed to remove ${arr[$i]} with sudo, skipping..."
				else
					cp "${arr[$i]}" "${WPATH}/drive_c/windows/syswow64/"
				fi
			fi
		else
			# Is not a sym link
			echo "syswow64/${arr[$i]} is not a sym link"
			if [[ -w "${WPATH}/drive_c/windows/syswow64/${arr[$i]}" ]]; then
				# Is writeable
				echo "syswow64/${arr[$i]} is normally writeable"
				cp "${arr[$i]}" "${WPATH}/drive_c/windows/syswow64/"
			else
				# Is not writeable
				echo "syswow64/${arr[$i]} is not normally writeable, need to use sudo"
				if ! gui_sudo cp "${arr[$i]}" "${WPATH}/drive_c/windows/syswow64/" 2>&1; then
					echo "Warning: Failed to copy ${arr[$i]} with sudo, skipping..."
				fi
			fi
		fi
	done
}

# Override dlls
function dll_override {
	"/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine" --bottle "$BOTTLE_NAME" --cx-app reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v $1 /d native /f
}

shopt -s nullglob

# Vars
VERBOSE=false
WPATH=""
NOCONFIRM=false
E=false
EPATH=""

# Main
if [[ -z $@ ]]; then
	print_help
fi
while test $# -gt 0; do
	case "$1" in
		(-v|--verbose)
			shift
			VERBOSE=true;;
		(-n|--noconfirm)
			shift
			NOCONFIRM=true;;
		(-h|--help)
			shift
			print_help;;
		(-e|--executable)
			shift
			exe_santiy "$1"
			shift;;
		(-d|--download-mediafoundation)
			shift
			echo "The media foundation download option is not implemented in this script. Please download the media foundation files manually."
			exit 7;;
		* )
			if [[ "$1" == -* ]]; then
				echo "Unknown option: $1"
				exit 1 # Error on unknown option
			else
				if [[ -d "$1" ]]; then
					WPATH="$1"
                    BOTTLE_NAME=$(basename "$WPATH")
					export WINEPREFIX="$1"
					shift
				else
					echo -e "Give path is not a valid directory:\n$1"
					exit 2 # Error on invalid dir path
				fi
			fi
	esac
done

# Check path is set correctly
sanity
# Exit immediately if a command exits with non-zero status
set -e
# Disable Wine debug messages
export WINEDEBUG="-all"
# Get directory of script
mydir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
# Copy dll files
run_copies
# Set Wine dll overrides
dll_override "colorcnv"
dll_override "mf"
dll_override "mferror"
dll_override "mfplat"
dll_override "mfplay"
dll_override "mfreadwrite"
dll_override "msmpeg2adec"
dll_override "msmpeg2vdec"
dll_override "sqmapi"

cd "$mydir"
# Function to dismiss RegSvr32 dialogs
dismiss_dialog() {
	# Wait a moment for dialog to appear, then dismiss it
	sleep 3
	# Try multiple times to catch the dialog
	for i in {1..5}; do
		osascript <<'EOF' 2>/dev/null || true
tell application "System Events"
	try
		-- Look for regsvr32.exe process with windows
		repeat with proc in (processes whose name contains "regsvr32" or name contains "RegSvr32" or name contains "regsvr32.exe")
			try
				if exists (window 1 of proc) then
					set frontmost of proc to true
					delay 0.5
					try
						-- Try to click OK button
						click button "OK" of window 1 of proc
					on error
						try
							-- Try pressing Return/Enter
							keystroke return
						on error
							-- Try Escape
							keystroke (ASCII character 27)
						end try
					end try
					delay 0.3
				end if
			end try
		end repeat
	end try
end tell
EOF
		sleep 1
	done
}

# Add registry keys into prefix
echo "Adding registry keys..."
"/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine" --bottle "$BOTTLE_NAME" --cx-app start regedit.exe mf.reg &
wine_pid=$!
dismiss_dialog
wait $wine_pid 2>/dev/null || true

"/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine" --bottle "$BOTTLE_NAME" --cx-app start regedit.exe wmf.reg &
wine_pid=$!
dismiss_dialog
wait $wine_pid 2>/dev/null || true

# Register dlls
echo "Registering DLLs (auto-dismissing dialogs)..."
"/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine" --bottle "$BOTTLE_NAME" --cx-app regsvr32 colorcnv.dll &
wine_pid=$!
dismiss_dialog
wait $wine_pid 2>/dev/null || true

"/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine" --bottle "$BOTTLE_NAME" --cx-app regsvr32 msmpeg2adec.dll &
wine_pid=$!
dismiss_dialog
wait $wine_pid 2>/dev/null || true

"/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine" --bottle "$BOTTLE_NAME" --cx-app regsvr32 msmpeg2vdec.dll &
wine_pid=$!
dismiss_dialog
wait $wine_pid 2>/dev/null || true
# Download the media foundation executable if needed
# if [ ! -f "windows6.1-KB976932-X64.exe" && ]; then
#     curl -o windows6.1-KB976932-X64.exe https://web.archive.org/web/20200803210804/https://download.microsoft.com/download/0/A/F/0AFB5316-3062-494A-AB78-7FB0D4461357/windows6.1-KB976932-X64.exe
# fi
# Use the installcab.py for previous fix because I don't have enough of an understanding of it to rewrite it for this script
#python2 installcab.py windows6.1-KB976932-X64.exe mediafoundation
#python2 installcab.py windows6.1-KB976932-X64.exe mf_
#python2 installcab.py windows6.1-KB976932-X64.exe mfreadwrite
#python2 installcab.py windows6.1-KB976932-X64.exe wmadmod
#python2 installcab.py windows6.1-KB976932-X64.exe wmvdecod
#python2 installcab.py windows6.1-KB976932-X64.exe wmadmod
# Message of copy mfplat.dll file if needed
if $E; then
	cp mfplat.dll "$EPATH"
	[ "$?" -eq 0 ] && echo -e "\nCopied mfplat.dll to given executable path" || echo -e "\nFailed to copy mfplat.dll. You will need to manually copy it to the game's directory."
else
	echo -e "\nNow you need to copy mfplat.dll to the game's directory"
fi