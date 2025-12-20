#!/usr/bin/env python3
"""
GUI application for finding and fixing CrossOver bottles for Futureport82.
"""

import os
import subprocess
import sys
from pathlib import Path
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QListWidget, QLabel, QLineEdit, QFileDialog,
    QMessageBox, QProgressBar, QTextEdit, QGroupBox, QInputDialog, QDialog, QDialogButtonBox, QCheckBox
)
from PyQt6.QtGui import QFont
from PyQt6.QtCore import Qt, QThread, pyqtSignal


class FixWorker(QThread):
    """Worker thread to run the fix script without blocking the UI."""
    finished = pyqtSignal(bool, str)
    output = pyqtSignal(str)
    
    def __init__(self, script_path, exe_path, bottle_dir, password=None, add_to_bottle=False):
        super().__init__()
        self.script_path = script_path
        self.exe_path = exe_path
        self.bottle_dir = bottle_dir
        self.password = password
        self.add_to_bottle = add_to_bottle
    
    def run(self):
        try:
            self.output.emit("Running fix script...\n")
            self.output.emit(f"Script path: {self.script_path}\n")
            self.output.emit("\n⚠️  IMPORTANT: Watch for CrossOver dialogs!\n")
            self.output.emit("   During the fix, CrossOver may show 'OK' dialogs in the dock.\n")
            self.output.emit("   Click on the CrossOver icon in the dock to see and dismiss them.\n")
            self.output.emit("   These dialogs won't interrupt the process, but need to be dismissed.\n\n")
            
            # Verify script exists and is executable
            if not os.path.exists(self.script_path):
                error_msg = f"Script not found: {self.script_path}"
                self.output.emit(f"Error: {error_msg}\n")
                self.finished.emit(False, error_msg)
                return
            
            # Set up environment with password if provided
            env = dict(os.environ, PYTHONUNBUFFERED='1')
            if self.password:
                env['GUI_SUDO_PASSWORD'] = self.password
                self.output.emit("Using provided administrator password.\n\n")
            else:
                self.output.emit("Note: Administrator privileges may be required.\n\n")
            
            # Set the resource directory for the script (where DLLs and registry files are)
            script_dir = os.path.dirname(self.script_path)
            env['MF_FIX_RESOURCE_DIR'] = script_dir
            self.output.emit(f"Resource directory: {script_dir}\n")
            
            # Verify required resources exist
            required_resources = ["system32", "syswow64", "mf.reg", "wmf.reg", "mfplat.dll"]
            missing = [r for r in required_resources if not os.path.exists(os.path.join(script_dir, r))]
            if missing:
                error_msg = f"Missing required resources: {', '.join(missing)} in {script_dir}"
                self.output.emit(f"Error: {error_msg}\n")
                self.finished.emit(False, error_msg)
                return
            
            # Use Popen for real-time output streaming
            # Run with bash explicitly and ensure script is executable
            # Set cwd to script directory so relative paths work
            process = subprocess.Popen(
                ["/bin/bash", self.script_path, "-e", self.exe_path, self.bottle_dir],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,  # Line buffered
                universal_newlines=True,
                env=env,
                cwd=script_dir
            )
            
            # Stream output in real-time
            output_lines = []
            import time
            import threading
            
            # Add a heartbeat to show the process is still running
            last_output_time = time.time()
            heartbeat_interval = 5  # Show heartbeat every 5 seconds
            
            def show_heartbeat():
                while process.poll() is None:
                    time.sleep(heartbeat_interval)
                    if time.time() - last_output_time > heartbeat_interval:
                        self.output.emit("... (still running, please wait) ...\n")
            
            heartbeat_thread = threading.Thread(target=show_heartbeat, daemon=True)
            heartbeat_thread.start()
            
            # Read output line by line
            while True:
                line = process.stdout.readline()
                if not line and process.poll() is not None:
                    break
                if line:
                    line = line.rstrip()
                    if line:  # Only emit non-empty lines
                        self.output.emit(line + "\n")
                        output_lines.append(line)
                        last_output_time = time.time()
            
            # Read any remaining output
            remaining = process.stdout.read()
            if remaining:
                for line in remaining.splitlines():
                    if line.strip():
                        self.output.emit(line.strip() + "\n")
                        output_lines.append(line.strip())
            
            # Wait for process to complete and get return code
            process.wait()
            return_code = process.returncode
            
            if return_code == 0:
                # If requested, add the application to the bottle
                if self.add_to_bottle:
                    self.output.emit("\nAdding Futureport82.exe to bottle as application...\n")
                    try:
                        self.add_application_to_bottle()
                        self.output.emit("Application added to bottle successfully!\n")
                    except Exception as e:
                        self.output.emit(f"Warning: Could not add application to bottle: {e}\n")
                        self.output.emit("You can manually add it later from CrossOver's application menu.\n")
                
                self.finished.emit(True, "Fix completed successfully!")
            else:
                error_msg = f"Script exited with code {return_code}"
                if output_lines:
                    error_msg += f"\n\nLast output:\n" + "\n".join(output_lines[-10:])
                self.output.emit(f"\nError: {error_msg}\n")
                self.finished.emit(False, error_msg)
                
        except FileNotFoundError as e:
            error_msg = f"Script not found: {e}"
            self.output.emit(f"Error: {error_msg}\n")
            self.finished.emit(False, error_msg)
        except Exception as e:
            import traceback
            error_details = traceback.format_exc()
            error_msg = f"Unexpected error: {e}\n\n{error_details}"
            self.output.emit(f"Error: {error_msg}\n")
            self.finished.emit(False, f"Unexpected error: {e}")
    
    def add_application_to_bottle(self):
        """Add the Futureport82.exe application to the CrossOver bottle."""
        import shutil
        
        # Get bottle name from path
        bottle_name = os.path.basename(self.bottle_dir)
        
        # Get the wine binary path
        wine_bin = "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
        
        if not os.path.exists(wine_bin):
            raise FileNotFoundError("CrossOver wine binary not found")
        
        bottle_drive_c = os.path.join(self.bottle_dir, "drive_c")
        exe_filename = os.path.basename(self.exe_path)
        
        # Check if the exe is inside the bottle
        if not self.exe_path.startswith(bottle_drive_c):
            # Get the directory containing the exe (this is the game's root directory)
            exe_dir = os.path.dirname(self.exe_path)
            
            # Copy the entire directory structure to preserve the game's file layout
            # The exe might be a launcher that expects the full directory structure
            # Use "Futureport82" as the target name for consistency
            target_base = os.path.join(bottle_drive_c, "Program Files")
            target_dir = os.path.join(target_base, "Futureport82")
            target_exe = os.path.join(target_dir, exe_filename)
            
            # Copy the entire source directory to preserve structure
            # This ensures Futureport82.exe can find Futureport82/Binaries/Win64/ etc.
            if not os.path.exists(target_dir):
                self.output.emit(f"Copying entire directory structure to bottle...\n")
                try:
                    shutil.copytree(exe_dir, target_dir, dirs_exist_ok=True)
                    self.output.emit(f"Copied directory structure to bottle.\n")
                except Exception as e:
                    # Fallback: copy just the exe if copytree fails
                    os.makedirs(target_dir, exist_ok=True)
                    shutil.copy2(self.exe_path, target_exe)
                    self.output.emit(f"Warning: Could not copy full directory, copied exe only: {e}\n")
            elif not os.path.exists(target_exe):
                # Directory exists but exe is missing, copy just the exe
                shutil.copy2(self.exe_path, target_exe)
                self.output.emit(f"Copied {exe_filename} to bottle.\n")
            
            wine_path = target_exe.replace(bottle_drive_c, "C:\\").replace("/", "\\")
        else:
            # Already in bottle, convert to Windows path
            wine_path = self.exe_path.replace(bottle_drive_c, "C:\\").replace("/", "\\")
        
        # Create a simple batch file shortcut that CrossOver can detect
        desktop_path = os.path.join(bottle_drive_c, "users", "crossover", "Desktop")
        os.makedirs(desktop_path, exist_ok=True)
        
        # Create a batch file that launches the application
        batch_file = os.path.join(desktop_path, "Futureport82.bat")
        batch_content = f'@echo off\ncd /d "{os.path.dirname(wine_path)}"\nstart "" "{wine_path}"\n'
        
        try:
            with open(batch_file, 'w', encoding='utf-8') as f:
                f.write(batch_content)
            self.output.emit("Created batch file shortcut on desktop.\n")
        except Exception as e:
            self.output.emit(f"Warning: Could not create batch file: {e}\n")
        
        # Also try to create a proper shortcut using VBScript, but with a strict timeout
        vbs_script = os.path.join(desktop_path, "create_shortcut.vbs")
        shortcut_path = os.path.join(desktop_path, "Futureport82.lnk")
        
        # Escape backslashes for VBScript
        wine_path_escaped = wine_path.replace("\\", "\\\\")
        shortcut_path_escaped = shortcut_path.replace("\\", "\\\\")
        working_dir_escaped = os.path.dirname(wine_path).replace("\\", "\\\\")
        
        vbs_content = f'''Set oWS = WScript.CreateObject("WScript.Shell")
sLinkFile = "{shortcut_path_escaped}"
Set oLink = oWS.CreateShortcut(sLinkFile)
oLink.TargetPath = "{wine_path_escaped}"
oLink.WorkingDirectory = "{working_dir_escaped}"
oLink.Description = "Futureport82"
oLink.Save
'''
        
        try:
            with open(vbs_script, 'w', encoding='utf-8') as f:
                f.write(vbs_content)
            
            # Run VBScript with strict timeout
            vbs_wine_path = vbs_script.replace(bottle_drive_c, "C:\\").replace("/", "\\")
            
            process = subprocess.Popen(
                [wine_bin, "--bottle", bottle_name, "--cx-app", "cscript.exe", "//nologo", vbs_wine_path],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            
            # Wait max 3 seconds
            import time
            try:
                process.wait(timeout=3)
                if process.returncode == 0:
                    self.output.emit("Created Windows shortcut successfully.\n")
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                self.output.emit("Skipped Windows shortcut creation (timed out).\n")
        except Exception as e:
            # Non-critical, just continue
            pass
        finally:
            # Always clean up VBScript
            if os.path.exists(vbs_script):
                try:
                    os.remove(vbs_script)
                except:
                    pass
        
        # Create Start Menu shortcut so CrossOver can detect it
        start_menu_path = os.path.join(bottle_drive_c, "users", "crossover", "AppData", "Roaming", "Microsoft", "Windows", "Start Menu", "Programs")
        os.makedirs(start_menu_path, exist_ok=True)
        
        # Create shortcut in Start Menu
        start_menu_shortcut = os.path.join(start_menu_path, "Futureport82.lnk")
        start_menu_vbs = os.path.join(start_menu_path, "create_startmenu_shortcut.vbs")
        
        start_menu_shortcut_escaped = start_menu_shortcut.replace("\\", "\\\\")
        
        start_menu_vbs_content = f'''Set oWS = WScript.CreateObject("WScript.Shell")
sLinkFile = "{start_menu_shortcut_escaped}"
Set oLink = oWS.CreateShortcut(sLinkFile)
oLink.TargetPath = "{wine_path_escaped}"
oLink.WorkingDirectory = "{working_dir_escaped}"
oLink.Description = "Futureport82"
oLink.Save
'''
        
        try:
            with open(start_menu_vbs, 'w', encoding='utf-8') as f:
                f.write(start_menu_vbs_content)
            
            start_menu_vbs_wine_path = start_menu_vbs.replace(bottle_drive_c, "C:\\").replace("/", "\\")
            
            process = subprocess.Popen(
                [wine_bin, "--bottle", bottle_name, "--cx-app", "cscript.exe", "//nologo", start_menu_vbs_wine_path],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            
            try:
                process.wait(timeout=3)
                if process.returncode == 0:
                    self.output.emit("Created Start Menu shortcut.\n")
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        except Exception as e:
            pass
        finally:
            if os.path.exists(start_menu_vbs):
                try:
                    os.remove(start_menu_vbs)
                except:
                    pass
        
        self.output.emit(f"Application available at: {wine_path}\n")
        self.output.emit("Note: You may need to restart CrossOver or refresh the bottle to see it in the application menu.\n")


def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller."""
    if getattr(sys, 'frozen', False):
        # Running as a bundled app
        base_path = sys._MEIPASS
    else:
        # Running as a script
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)


def get_version():
    """Get the application version from VERSION.md file."""
    try:
        version_file = resource_path("VERSION.md")
        if os.path.exists(version_file):
            with open(version_file, 'r') as f:
                version = f.read().strip()
                return version
    except Exception:
        pass
    return "dev"


class BottleManagerGUI(QMainWindow):
    def __init__(self):
        super().__init__()
        self.crossover_app = None
        self.cxwine = None
        self.selected_bottle = None
        self.selected_bottle_path = None
        self.fp82_exe_path = None
        self.init_ui()
        self.find_crossover()
        self.refresh_bottles()
    
    def init_ui(self):
        """Initialize the user interface."""
        version = get_version()
        self.setWindowTitle(f"Futureport82 CrossOver Bottle Fixer v{version}")
        self.setMinimumSize(700, 600)
        
        # Central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setSpacing(15)
        main_layout.setContentsMargins(20, 20, 20, 20)
        
        # Title
        version = get_version()
        title = QLabel("Futureport82 CrossOver Bottle Fixer")
        title_font = QFont()
        title_font.setPointSize(18)
        title_font.setBold(True)
        title.setFont(title_font)
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        main_layout.addWidget(title)
        
        # Version label
        version_label = QLabel(f"Version {version}")
        version_font = QFont()
        version_font.setPointSize(10)
        version_label.setFont(version_font)
        version_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        version_label.setStyleSheet("color: #666;")
        main_layout.addWidget(version_label)
        
        # CrossOver status
        self.crossover_status = QLabel("Checking for CrossOver...")
        self.crossover_status.setStyleSheet("color: #666; padding: 5px;")
        main_layout.addWidget(self.crossover_status)
        
        # Bottles group
        bottles_group = QGroupBox("CrossOver Bottles")
        bottles_layout = QVBoxLayout()
        
        # Bottle list
        self.bottle_list = QListWidget()
        self.bottle_list.setMinimumHeight(150)
        self.bottle_list.itemSelectionChanged.connect(self.on_bottle_selected)
        bottles_layout.addWidget(QLabel("Select a bottle:"))
        bottles_layout.addWidget(self.bottle_list)
        
        # Bottle buttons
        bottle_buttons = QHBoxLayout()
        self.create_bottle_btn = QPushButton("Create New Bottle")
        self.create_bottle_btn.clicked.connect(self.create_bottle_dialog)
        self.remove_bottle_btn = QPushButton("Remove Selected Bottle")
        self.remove_bottle_btn.clicked.connect(self.remove_bottle)
        self.refresh_btn = QPushButton("Refresh")
        self.refresh_btn.clicked.connect(self.refresh_bottles)
        
        bottle_buttons.addWidget(self.create_bottle_btn)
        bottle_buttons.addWidget(self.remove_bottle_btn)
        bottle_buttons.addWidget(self.refresh_btn)
        bottles_layout.addLayout(bottle_buttons)
        
        bottles_group.setLayout(bottles_layout)
        main_layout.addWidget(bottles_group)
        
        # Futureport82 executable selection
        exe_group = QGroupBox("Futureport82 Executable")
        exe_layout = QVBoxLayout()
        
        exe_input_layout = QHBoxLayout()
        self.exe_path_input = QLineEdit()
        self.exe_path_input.setPlaceholderText("Select the Futureport82 executable or its directory...")
        self.exe_browse_btn = QPushButton("Browse...")
        self.exe_browse_btn.clicked.connect(self.browse_exe)
        
        exe_input_layout.addWidget(self.exe_path_input)
        exe_input_layout.addWidget(self.exe_browse_btn)
        exe_layout.addLayout(exe_input_layout)
        
        # Checkbox to add application to bottle
        self.add_to_bottle_checkbox = QCheckBox("Add Futureport82.exe to bottle as application (recommended)")
        self.add_to_bottle_checkbox.setChecked(True)  # Default to checked
        exe_layout.addWidget(self.add_to_bottle_checkbox)
        
        exe_group.setLayout(exe_layout)
        main_layout.addWidget(exe_group)
        
        # Output/Log area
        log_group = QGroupBox("Output")
        log_layout = QVBoxLayout()
        self.output_text = QTextEdit()
        self.output_text.setReadOnly(True)
        self.output_text.setMaximumHeight(150)
        self.output_text.setFont(QFont("Monaco", 10))
        log_layout.addWidget(self.output_text)
        log_group.setLayout(log_layout)
        main_layout.addWidget(log_group)
        
        # Apply fix button
        self.apply_fix_btn = QPushButton("Apply Media Foundation Fix")
        self.apply_fix_btn.setStyleSheet("""
            QPushButton {
                background-color: #007AFF;
                color: white;
                font-size: 14px;
                font-weight: bold;
                padding: 10px;
                border-radius: 5px;
            }
            QPushButton:hover {
                background-color: #0051D5;
            }
            QPushButton:disabled {
                background-color: #CCCCCC;
                color: #666666;
            }
        """)
        self.apply_fix_btn.clicked.connect(self.apply_fix)
        self.apply_fix_btn.setEnabled(False)
        main_layout.addWidget(self.apply_fix_btn)
        
        # Status bar with version
        version = get_version()
        self.statusBar().showMessage(f"Ready - Version {version}")
    
    def find_crossover(self):
        """Find the CrossOver application."""
        default_path = "/Applications/CrossOver.app"
        if os.path.exists(default_path):
            self.crossover_app = default_path
            self.cxwine = os.path.join(default_path, "Contents/SharedSupport/CrossOver/bin/cxbottle")
            if os.path.exists(self.cxwine):
                self.crossover_status.setText(f"✓ CrossOver found at: {default_path}")
                self.crossover_status.setStyleSheet("color: #28A745; padding: 5px;")
            else:
                self.crossover_status.setText("✗ CrossOver found but cxbottle not found")
                self.crossover_status.setStyleSheet("color: #DC3545; padding: 5px;")
                self.crossover_app = None
        else:
            self.crossover_status.setText("✗ CrossOver not found at /Applications/CrossOver.app")
            self.crossover_status.setStyleSheet("color: #DC3545; padding: 5px;")
            QMessageBox.critical(
                self,
                "CrossOver Not Found",
                "CrossOver application not found at /Applications/CrossOver.app\n\n"
                "Please install CrossOver or ensure it's in the Applications folder."
            )
    
    def refresh_bottles(self):
        """Refresh the list of bottles."""
        if not self.crossover_app:
            return
        
        self.bottle_list.clear()
        default_bottle_location = os.path.expanduser("~/Library/Application Support/CrossOver/Bottles")
        
        if os.path.exists(default_bottle_location):
            bottles = []
            for item in os.listdir(default_bottle_location):
                item_path = os.path.join(default_bottle_location, item)
                if os.path.isdir(item_path):
                    bottles.append(item)
            
            if bottles:
                self.bottle_list.addItems(sorted(bottles))
                self.statusBar().showMessage(f"Found {len(bottles)} bottle(s)")
            else:
                self.bottle_list.addItem("(No bottles found)")
                self.statusBar().showMessage("No bottles found")
        else:
            self.bottle_list.addItem("(Bottles directory not found)")
            self.statusBar().showMessage("Bottles directory not found")
    
    def on_bottle_selected(self):
        """Handle bottle selection."""
        selected_items = self.bottle_list.selectedItems()
        if selected_items:
            self.selected_bottle = selected_items[0].text()
            default_bottle_location = os.path.expanduser("~/Library/Application Support/CrossOver/Bottles")
            self.selected_bottle_path = os.path.join(default_bottle_location, self.selected_bottle)
            self.update_apply_button_state()
        else:
            self.selected_bottle = None
            self.selected_bottle_path = None
            self.update_apply_button_state()
    
    def create_bottle_dialog(self):
        """Show dialog to create a new bottle."""
        from PyQt6.QtWidgets import QInputDialog
        
        bottle_name, ok = QInputDialog.getText(
            self,
            "Create New Bottle",
            "Enter bottle name:",
            text="futureport82"
        )
        
        if ok and bottle_name:
            bottle_name = bottle_name.strip()
            if bottle_name:
                self.create_bottle(bottle_name)
    
    def create_bottle(self, bottle_name: str):
        """Create a new bottle."""
        if not self.cxwine:
            QMessageBox.warning(self, "Error", "CrossOver not found. Cannot create bottle.")
            return
        
        try:
            self.statusBar().showMessage("Creating bottle...")
            self.output_text.append(f"Creating bottle: {bottle_name}...\n")
            
            flags = (
                f"--bottle {bottle_name} "
                f"--description 'Bottle for futureport82' "
                f"--template win10_64 "
                f"--create "
                f"--param 'EnvironmentVariables:CX_GRAPHICS_BACKEND=d3dmetal'"
            )
            
            result = subprocess.run(
                f"{self.cxwine} {flags}",
                shell=True,
                capture_output=True,
                text=True,
                check=True
            )
            
            self.output_text.append(result.stdout)
            self.output_text.append("Bottle created successfully!\n")
            self.statusBar().showMessage("Bottle created successfully")
            QMessageBox.information(self, "Success", f"Bottle '{bottle_name}' created successfully!")
            self.refresh_bottles()
            
            # Select the newly created bottle
            items = self.bottle_list.findItems(bottle_name, Qt.MatchFlag.MatchExactly)
            if items:
                self.bottle_list.setCurrentItem(items[0])
        except subprocess.CalledProcessError as e:
            error_msg = f"Error creating bottle: {e}\n{e.stderr if e.stderr else ''}"
            self.output_text.append(error_msg)
            QMessageBox.critical(self, "Error", f"Failed to create bottle:\n{error_msg}")
            self.statusBar().showMessage("Failed to create bottle")
    
    def remove_bottle(self):
        """Remove the selected bottle."""
        selected_items = self.bottle_list.selectedItems()
        if not selected_items:
            QMessageBox.warning(self, "No Selection", "Please select a bottle to remove.")
            return
        
        bottle_name = selected_items[0].text()
        
        reply = QMessageBox.question(
            self,
            "Confirm Removal",
            f"Are you sure you want to remove bottle '{bottle_name}'?\n\nThis action cannot be undone.",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        
        if reply == QMessageBox.StandardButton.Yes:
            if not self.cxwine:
                QMessageBox.warning(self, "Error", "CrossOver not found. Cannot remove bottle.")
                return
            
            try:
                self.statusBar().showMessage("Removing bottle...")
                flags = f"--bottle {bottle_name} --delete --force"
                subprocess.run(
                    f"{self.cxwine} {flags}",
                    shell=True,
                    capture_output=True,
                    text=True,
                    check=True
                )
                self.output_text.append(f"Bottle '{bottle_name}' removed successfully.\n")
                self.statusBar().showMessage("Bottle removed")
                QMessageBox.information(self, "Success", f"Bottle '{bottle_name}' removed successfully!")
                self.refresh_bottles()
            except subprocess.CalledProcessError as e:
                error_msg = f"Error removing bottle: {e}\n{e.stderr if e.stderr else ''}"
                self.output_text.append(error_msg)
                QMessageBox.critical(self, "Error", f"Failed to remove bottle:\n{error_msg}")
                self.statusBar().showMessage("Failed to remove bottle")
    
    def browse_exe(self):
        """Browse for Futureport82 executable."""
        file_path, _ = QFileDialog.getOpenFileName(
            self,
            "Select Futureport82 Executable",
            "",
            "Executable Files (*.exe);;All Files (*)"
        )
        
        if file_path:
            # If it's a file, use its directory; if it's a directory, use it directly
            if os.path.isfile(file_path):
                self.fp82_exe_path = file_path
            else:
                self.fp82_exe_path = file_path
            self.exe_path_input.setText(self.fp82_exe_path)
            self.update_apply_button_state()
    
    def update_apply_button_state(self):
        """Update the apply fix button state based on selections."""
        can_apply = (
            self.selected_bottle_path is not None and
            self.fp82_exe_path is not None and
            os.path.exists(self.fp82_exe_path) and
            self.crossover_app is not None
        )
        self.apply_fix_btn.setEnabled(can_apply)
    
    def apply_fix(self):
        """Apply the media foundation fix."""
        try:
            if not self.selected_bottle_path or not self.fp82_exe_path:
                QMessageBox.warning(self, "Missing Information", "Please select a bottle and Futureport82 executable.")
                return
            
            # Get the script path (handle both development and bundled app cases)
            try:
                fix_script = resource_path("mf-fix-cx.sh")
            except Exception as e:
                QMessageBox.critical(
                    self,
                    "Error",
                    f"Failed to locate fix script:\n{e}\n\nPlease ensure mf-fix-cx.sh is bundled with the app."
                )
                return
            
            # Make sure script is executable (skip silently if in read-only location like App Translocation)
            script_dir = os.path.dirname(fix_script)
            if os.path.exists(fix_script):
                try:
                    # Check if we can write to the directory before trying to chmod
                    if os.access(script_dir, os.W_OK):
                        os.chmod(fix_script, 0o755)
                    # If in read-only location (App Translocation), bash can still execute the script
                    # so we silently continue - no need to show an error or warning
                except Exception:
                    # Non-critical, bash can execute scripts even without executable bit
                    pass
            else:
                QMessageBox.critical(
                    self,
                    "Script Not Found",
                    f"Fix script not found at:\n{fix_script}\n\nPlease ensure mf-fix-cx.sh is bundled with the app."
                )
                return
            
            # Verify required resources exist (for bundled app)
            script_dir = os.path.dirname(fix_script)
            
            # Check if we're in App Translocation (read-only location)
            if 'AppTranslocation' in fix_script:
                reply = QMessageBox.warning(
                    self,
                    "App Translocation Detected",
                    "The app is running from a read-only location (App Translocation).\n\n"
                    "This can cause issues. It's recommended to move Futureport82Fixer.app\n"
                    "to your Applications folder and run it from there.\n\n"
                    "Would you like to continue anyway?",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                    QMessageBox.StandardButton.No
                )
                if reply == QMessageBox.StandardButton.No:
                    return
            required_files = ["system32", "syswow64", "mf.reg", "wmf.reg", "mfplat.dll"]
            missing_files = []
            for req_file in required_files:
                req_path = os.path.join(script_dir, req_file)
                if not os.path.exists(req_path):
                    missing_files.append(req_file)
            
            if missing_files:
                QMessageBox.critical(
                    self,
                    "Missing Resources",
                    f"The following required files are missing:\n{', '.join(missing_files)}\n\n"
                    f"Expected location: {script_dir}\n\n"
                    f"This may indicate a problem with the app bundle."
                )
                return
            
            # Confirm before proceeding
            reply = QMessageBox.question(
                self,
                "Confirm Fix",
                f"Apply media foundation fix to:\n\n"
                f"Bottle: {self.selected_bottle}\n"
                f"Executable: {self.fp82_exe_path}\n\n"
                f"⚠️ IMPORTANT: During the fix, CrossOver may show 'OK' dialogs.\n"
                f"   Watch the dock and click the CrossOver icon to dismiss them.\n\n"
                f"This may require administrator privileges.",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                QMessageBox.StandardButton.Yes
            )
            
            if reply == QMessageBox.StandardButton.Yes:
                # Prompt for administrator password using QInputDialog
                # In PyQt6, getText signature is: getText(parent, title, label, echo=Normal, text="")
                password, ok = QInputDialog.getText(
                    self,
                    "Administrator Password Required",
                    "This operation requires administrator privileges.\n\nEnter your password:",
                    echo=QLineEdit.EchoMode.Password
                )
                
                if not ok or not password:
                    self.statusBar().showMessage("Fix cancelled by user")
                    return
                
                self.apply_fix_btn.setEnabled(False)
                self.statusBar().showMessage("Applying fix...")
                self.output_text.clear()
                self.output_text.append("Starting media foundation fix...\n")
                self.output_text.append(f"Bottle: {self.selected_bottle_path}\n")
                self.output_text.append(f"Executable: {self.fp82_exe_path}\n\n")
                
                # Run fix in worker thread with password and add_to_bottle option
                try:
                    add_to_bottle = self.add_to_bottle_checkbox.isChecked()
                    self.worker = FixWorker(fix_script, self.fp82_exe_path, self.selected_bottle_path, password, add_to_bottle)
                    self.worker.output.connect(self.output_text.append)
                    self.worker.finished.connect(self.on_fix_finished)
                    self.worker.start()
                except Exception as e:
                    import traceback
                    error_details = traceback.format_exc()
                    QMessageBox.critical(
                        self,
                        "Error Starting Fix",
                        f"Failed to start fix process:\n{e}\n\n{error_details}"
                    )
                    self.apply_fix_btn.setEnabled(True)
                    self.statusBar().showMessage("Failed to start fix")
        except Exception as e:
            import traceback
            error_details = traceback.format_exc()
            QMessageBox.critical(
                self,
                "Unexpected Error",
                f"An unexpected error occurred:\n{e}\n\n{error_details}"
            )
            self.apply_fix_btn.setEnabled(True)
            self.statusBar().showMessage("Error occurred")
    
    def on_fix_finished(self, success: bool, message: str):
        """Handle fix completion."""
        try:
            self.apply_fix_btn.setEnabled(True)
            if success:
                self.statusBar().showMessage("Fix completed successfully!")
                QMessageBox.information(self, "Success", message)
            else:
                self.statusBar().showMessage("Fix failed")
                QMessageBox.critical(self, "Error", message)
        except Exception as e:
            import traceback
            error_details = traceback.format_exc()
            # Use a simple print to avoid potential recursive issues
            print(f"Error in on_fix_finished: {e}\n{error_details}")
            self.apply_fix_btn.setEnabled(True)
            self.statusBar().showMessage("Error handling fix completion")


def main():
    app = QApplication(sys.argv)
    app.setStyle("macos")  # Use native macOS style
    
    window = BottleManagerGUI()
    window.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()

