
#!/usr/bin/env python3

import os
import subprocess
import sys
from pathlib import Path
import shutil
import tempfile
from datetime import datetime

def log(msg):
    """Prints an informational message."""
    print(f"[INFO] {datetime.now()} - {msg}")

def error(msg):
    """Prints an error message and exits."""
    print(f"[ERROR] {datetime.now()} - {msg}", file=sys.stderr)
    sys.exit(1)

def check_command(cmd):
    """Checks if a command exists in the system's PATH."""
    if not shutil.which(cmd):
        error(f"Required command '{cmd}' not found. Exiting.")
    log(f"Found command: {cmd}")

def run(cmd, cwd=None, check=True):
    """Runs a command and logs its output."""
    log(f"Running: {' '.join(cmd)}")
    try:
        result = subprocess.run(cmd, cwd=cwd, check=check, capture_output=True, text=True)
        if result.stdout:
            print(result.stdout)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        return result
    except subprocess.CalledProcessError as e:
        error(f"Command failed: {' '.join(cmd)}\nStdout: {e.stdout}\nStderr: {e.stderr}")
    except FileNotFoundError:
        error(f"Command not found: {cmd}")

def set_permissions(path, read_only=True):
    """Recursively sets permissions for a directory."""
    mode_str = "read-only" if read_only else "writable for user"
    log(f"Setting {path} to {mode_str}...")
    try:
        for root, dirs, files in os.walk(path):
            for d in dirs:
                os.chmod(os.path.join(root, d), 0o555 if read_only else 0o755)
            for f in files:
                os.chmod(os.path.join(root, f), 0o444 if read_only else 0o644)
    except OSError as e:
        error(f"Failed to set permissions on {path}: {e}")

def is_debian_based():
    """Check if the OS is Debian-based."""
    return os.path.exists("/etc/debian_version")

def install_gh():
    """Installs the GitHub CLI if not present."""
    if shutil.which("gh"):
        log("GitHub CLI (gh) is already installed.")
        return

    if not is_debian_based():
        error("This script can only install GitHub CLI on Debian-based systems.")

    log("GitHub CLI (gh) not found. Installing...")
    try:
        keyrings_dir = Path("/etc/apt/keyrings")
        if not keyrings_dir.is_dir():
            run(["sudo", "mkdir", "-p", "-m", "755", str(keyrings_dir)])

        keyring_url = "https://cli.github.com/packages/githubcli-archive-keyring.gpg"
        keyring_path = keyrings_dir / "githubcli-archive-keyring.gpg"
        
        with tempfile.NamedTemporaryFile(delete=False) as tmp:
            run(["wget", "-qO", tmp.name, keyring_url])
            run(["sudo", "mv", tmp.name, str(keyring_path)])

        run(["sudo", "chmod", "go+r", str(keyring_path)])

        arch = subprocess.check_output(["dpkg", "--print-architecture"]).decode("utf-8").strip()
        sources_list_path = "/etc/apt/sources.list.d/github-cli.list"
        sources_list_content = f"deb [arch={arch} signed-by={keyring_path}] https://cli.github.com/packages stable main"
        
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as tmp:
            tmp.write(sources_list_content)
            tmp_path = tmp.name
        
        run(["sudo", "mv", tmp_path, sources_list_path])

        run(["sudo", "apt-get", "update"])
        run(["sudo", "apt-get", "install", "-y", "gh"])
        log("GitHub CLI installed successfully.")

    except Exception as e:
        error(f"Failed to install GitHub CLI: {e}")

def main():
    print(f"===== post-create.py START - {datetime.now()} =====")

    log("Checking for required commands and directories...")
    install_gh()
    for cmd in ["git", "python3", "pip", "gh"]:
        check_command(cmd)

    workspaces_dir = Path("/workspaces")
    if not workspaces_dir.is_dir():
        error("/workspaces directory does not exist. Exiting.")
    log("/workspaces directory exists.")

    repo_name = os.environ.get("GITHUB_REPOSITORY", "adk-agents-golden").split("/")[-1]
    root_dir = Path(f"/workspaces/{repo_name}")
    if not root_dir.is_dir():
        root_dir = Path("/workspaces/adk-agents-golden")
    
    os.chdir(root_dir)
    log(f"Changed directory to {os.getcwd()}")

    reference_dir = Path("/workspaces/adk-reference-repos")
    reference_dir.mkdir(parents=True, exist_ok=True)
    log(f"Cloning reference repositories into {reference_dir}")

    repos = [
        ("adk-python", "https://github.com/google/adk-python"),
        ("adk-samples", "https://github.com/google/adk-samples"),
        ("adk-docs", "https://github.com/google/adk-docs"),
        ("adk-python-community", "https://github.com/google/adk-python-community"),
    ]
    for name, url in repos:
        repo_path = reference_dir / name
        if not repo_path.is_dir():
            log(f"Cloning {name} from {url}")
            run(["git", "clone", url, str(repo_path)])
        else:
            log(f"{name} already exists, making it writable to pull latest changes.")
            set_permissions(repo_path, read_only=False)
            run(["git", "pull"], cwd=str(repo_path))
        
        set_permissions(repo_path, read_only=True)

    os.chdir(root_dir)
    log(f"Changed directory back to {os.getcwd()}")

    venv_dir = root_dir / ".venv"
    if not venv_dir.is_dir():
        log("Creating Python virtual environment...")
        run([sys.executable, "-m", "venv", str(venv_dir)])
    else:
        log("Virtual environment already exists.")

    python_executable = venv_dir / "bin/python"
    if not python_executable.is_file():
        error("Python executable not found in virtual environment.")
    log(f"Virtual environment successfully verified at {venv_dir}")

    log("Upgrading pip...")
    run([str(python_executable), "-m", "pip", "install", "--upgrade", "pip"])
    
    requirements_path = root_dir / "requirements.txt"
    if requirements_path.is_file():
        log("Installing dependencies from requirements.txt...")
        run([str(python_executable), "-m", "pip", "install", "-r", str(requirements_path)])
    else:
        log(f"Virtual environment successfully verified at {venv_dir}")

    # Install dependencies from requirements.txt if present
    log("Upgrading pip...")
    run([str(venv_dir / "bin/pip"), "install", "--upgrade", "pip"])
    requirements_path = root_dir / "requirements.txt"
    if requirements_path.is_file():
        log("Installing dependencies from requirements.txt...")
        run([str(venv_dir / "bin/pip"), "install", "-r", str(requirements_path)])
    else:
        log("Warning: requirements.txt not found. Skipping dependency installation.")

    print("===== post-create.py END =====")
    print(datetime.now())

if __name__ == "__main__":
    main()
