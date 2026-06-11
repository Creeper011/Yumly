{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "yumly-dev-shell";

  buildInputs = with pkgs; [
    # Nim environment
    nim
    nimble

    # Python environment (3.12)
    python312Packages.python
    python312Packages.pip
    python312Packages.venvShellHook

    # Build tools
    gcc
    gnumake
    pkg-config
    openssl

    # Versionament tools
    git
    ];

    venvDir = "./.venv";

    postShellHook = ''
    # Automated dependency setup
    echo "Checking dependencies..."
    
    # 1. Nim dependencies
    if [ ! -d "$HOME/.nimble/pkgs" ]; then
      echo "Installing Nim dependencies..."
      nimble install -y nimpy dotenv --silent
    fi

    # 2. Python dependencies (auto-installs in .venv via venvShellHook)
    if [ -f "requirements-dev.txt" ]; then
      echo "Installing/Updating Python dev dependencies..."
      pip install -r requirements-dev.txt --silent
    fi

    # 3. Project install (editable mode)
    pip install -e . --silent

    export PATH="$PATH:$HOME/.nimble/bin"
    
    clear
    echo "✧*･ﾟ Yumly Development Shell Loaded ･ﾟ*✧"
    echo "Python: $(python --version)"
    echo "Nim:    $(nim --version | head -n 1)"
    echo "Environment: .venv is active and dependencies are ready."
  '';
}
