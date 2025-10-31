#!/bin/bash
#
# Generate Infrastructure Diagram
#
# This script creates a visual diagram of the entire Terraform infrastructure.
# It sets up a virtual environment if needed and runs the Python diagram generator.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🎨 Generating Infrastructure Diagram..."
echo ""

# Check if Graphviz is installed
if ! command -v dot &> /dev/null; then
    echo "❌ Error: Graphviz is not installed"
    echo ""
    echo "Please install Graphviz first:"
    echo "  macOS:        brew install graphviz"
    echo "  Ubuntu/Debian: sudo apt-get install graphviz"
    echo "  Windows:      choco install graphviz"
    exit 1
fi

# Create virtual environment if it doesn't exist
# Check if python3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 is not installed"
    echo ""
    echo "Please install Python 3 first:"
    echo "  macOS:         brew install python3"
    echo "  Ubuntu/Debian: sudo apt-get install python3"
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment and install/upgrade diagrams
echo "📥 Installing/updating dependencies..."
source venv/bin/activate
pip install -q --upgrade pip
pip install -q diagrams

# Generate diagram
echo "🔨 Generating diagram..."
python3 infrastructure_diagram.py

# Deactivate virtual environment
deactivate

echo ""
echo "✅ Done! Diagram saved to: infrastructure.png"
echo ""
echo "To view the diagram:"
echo "  macOS: open infrastructure.png"
echo "  Linux: xdg-open infrastructure.png"
