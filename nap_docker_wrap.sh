#!/bin/bash
set -e
# Help
show_help() {
    cat <<EOF
Usage:
  nap_activate [directory]
        or
  nap_activate -h | --help

What it does:
  Opens the NAP Docker image in the chosen directory, with that directory
  mounted inside the container at the same path. 
  Ensure the chosen directory contains all required files
  If no directory is given, current directory is used.
EOF
}
# Help controller
if [ $# -gt 0 ] && { [ "$1" = "-h" ] || [ "$1" = "--help" ]; }; then
    show_help
    exit 0
fi
# Path given or use ./ (current directoy)
if [ $# -eq 0 ]; then
    load_dir="$PWD"
else
    load_dir="$1"
    shift
fi
load_dir="$(realpath "$load_dir")"
# valid directory?
if [ ! -d "$load_dir" ]; then
    echo "ERROR: directory not found: $load_dir" >&2
    exit 1
fi

# Docker running command
docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  -v "$load_dir":"$load_dir" \
  -w "$load_dir" \
  nap:latest
