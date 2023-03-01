#!/usr/bin/env bash

# Exit if anything fails.
set -euo pipefail

# If argument not provided, print usage and exit
if [ $# -ne 1 ]; then
    echo "Usage: bin/generate_practice_exercise.sh <exercise-slug>"
    exit 1
fi

# Check if sed is gnu-sed
if ! sed --version | grep -q "GNU sed"; then
    echo "GNU sed is required. Please install it and make sure it's in your PATH."
    exit 1
fi

# Check if jq and curl are installed
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is required but not installed. Aborting."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo >&2 "curl is required but not installed. Aborting."; exit 1; }

# Shows a success message if process is successful
function success() {
    if [ $? -eq 0 ]; then
        printf "\033[32m%s\033[0m\n" "[success]: $1"
    fi
}

function all_done() {
    if [ $? -eq 0 ]; then
        printf "\033[1;32m%s\033[0m\n" "[done]: $1"
    fi
}



SLUG="$1"
EXERCISE_DIR="exercises/practice/${SLUG}"


echo "Creating Rust files"
cargo new --lib "$EXERCISE_DIR" -q
mkdir -p ${EXERCISE_DIR}/tests

cat <<EOT > "$EXERCISE_DIR"/.gitignore
# Generated by Cargo
# Will have compiled files and executables
/target/
**/*.rs.bk

# Remove Cargo.lock from gitignore if creating an executable, leave it for libraries
# More information here http://doc.crates.io/guide.html#cargotoml-vs-cargolock
Cargo.lock
EOT
success "Created Rust files, tests dir and updated gitignore!"

download() {
    local FILE="$1"
    local URL="$2"
    curl --silent --show-error --fail --retry 3 --max-time 3 \
    --output "$FILE" "$URL"
}

# build configlet
echo "Fetching configlet"
./bin/fetch-configlet
success "Fetched configlet successfully!"


# Preparing config.json
echo "Adding instructions and configuration files..."
UUID=$(bin/configlet uuid)
jq --arg slug "$SLUG" --arg uuid "$UUID" \
'.exercises.practice += [{slug: $slug, name: "TODO", uuid: $uuid, practices: [], prerequisites: [], difficulty: 5}]' \
config.json > config.json.tmp
# jq always rounds whole numbers, but average_run_time needs to be a float
sed -i 's/"average_run_time": \([0-9]\+\)$/"average_run_time": \1.0/' config.json.tmp
mv config.json.tmp config.json
success "Added instructions and configuration files successfully!"

# Create instructions and config files
echo "Creating instructions and config files"
./bin/configlet sync --update --yes --docs --metadata --exercise "$SLUG"
./bin/configlet sync --update --yes --filepaths --exercise "$SLUG"
./bin/configlet sync --update --tests include --exercise "$SLUG"
success "Created instructions and config files"



NAME=$(echo $SLUG | sed 's/-/_/g' )
sed -i "s/name = \".*\"/name = \"$NAME\"/" "$EXERCISE_DIR"/Cargo.toml



echo
# Prints a line of dashes that's as wide as the screen
cols=$(tput cols)
printf "%*s\n" $cols | tr " " "-"
echo

all_done "All stub files were created."

echo "After implementing the solution, tests and configuration, please run:"
echo "./bin/configlet fmt --update --yes --exercise ${SLUG}"
