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
    pkg-config
    openssl

    # Benchmark tools
    hyperfine
    perf

    # Versionament tools
    git
    ];

    venvDir = "./.venv";

    postShellHook = ''
    # Automated dependency setup
    echo "Checking dependencies..."
    export NIMBLE_DIR="$PWD/build/nimble"
    
    # 1. Nim dependencies
    if [ ! -d "$NIMBLE_DIR/pkgs2" ]; then
      echo "Installing Nim dependencies..."
      nimble install -y nimpy dotenv yaml --silent
    fi

    # 2. Python dependencies (auto-installs in .venv via venvShellHook)
    if [ -f "requirements-dev.txt" ]; then
      echo "Installing/Updating Python dev dependencies..."
      pip install -r requirements-dev.txt --silent
    fi

    # 3. Project install (editable mode)
    pip install -e . --silent

    export PATH="$PATH:$NIMBLE_DIR/bin"
    
    clear
    echo "✧*･ﾟ Yumly Cute Development Shell Loaded >,< ･ﾟ*✧"
    echo "Python: $(python --version)"
    echo "Nim:    $(nim --version | head -n 1)"
    echo "yeaaaahh :3"
    echo "Available tools: $(
      for tool in nim nimble python pip gcc pkg-config openssl hyperfine perf git; do
        if command -v "$tool" >/dev/null 2>&1; then
          printf '%s ' "$tool;"
        fi
      done
    )"
  '';
}
