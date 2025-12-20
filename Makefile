
go-fast:
	@PYTHON_CMD=""; \
	if command -v python3 &>/dev/null; then \
		PYTHON_CMD="python3"; \
	elif command -v python &>/dev/null && python --version 2>&1 | grep -q "Python 3"; then \
		PYTHON_CMD="python"; \
	elif [ -x "/opt/homebrew/bin/python3" ]; then \
		PYTHON_CMD="/opt/homebrew/bin/python3"; \
	elif [ -x "/usr/local/bin/python3" ]; then \
		PYTHON_CMD="/usr/local/bin/python3"; \
	elif [ -x "/usr/bin/python3" ]; then \
		PYTHON_CMD="/usr/bin/python3"; \
	fi; \
	if [ -n "$$PYTHON_CMD" ]; then \
		echo "Using Python: $$PYTHON_CMD"; \
		$$PYTHON_CMD ./find-bottles.py; \
	else \
		echo "Python 3 is not installed or not found. Please install Python 3 to run this script."; \
		echo "On macOS, you can install it with: brew install python3"; \
		exit 1; \
	fi

gui:
	@PYTHON_CMD=""; \
	if command -v python3 &>/dev/null; then \
		PYTHON_CMD="python3"; \
	elif command -v python &>/dev/null && python --version 2>&1 | grep -q "Python 3"; then \
		PYTHON_CMD="python"; \
	elif [ -x "/opt/homebrew/bin/python3" ]; then \
		PYTHON_CMD="/opt/homebrew/bin/python3"; \
	elif [ -x "/usr/local/bin/python3" ]; then \
		PYTHON_CMD="/usr/local/bin/python3"; \
	elif [ -x "/usr/bin/python3" ]; then \
		PYTHON_CMD="/usr/bin/python3"; \
	fi; \
	if [ -n "$$PYTHON_CMD" ]; then \
		echo "Using Python: $$PYTHON_CMD"; \
		if ! $$PYTHON_CMD -c "import PyQt6" 2>/dev/null; then \
			echo "PyQt6 not found. Installing dependencies..."; \
			$$PYTHON_CMD -m pip install -q -r requirements.txt; \
		fi; \
		$$PYTHON_CMD ./find-bottles-gui.py; \
	else \
		echo "Python 3 is not installed or not found. Please install Python 3 to run this script."; \
		echo "On macOS, you can install it with: brew install python3"; \
		exit 1; \
	fi

