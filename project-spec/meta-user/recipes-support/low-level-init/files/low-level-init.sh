#!/bin/sh
# low-level-init.sh
# Unified script to call multiple initialization scripts in sequence

set -e

echo "##---Starting low-level initialization sequence---" > /dev/console

# Source profile scripts if they exist
for file in /etc/profile.d/zsys*; do
	if [ -f "$file" ]; then
		echo "Sourcing $file" > /dev/console
		. "$file"
	fi
done

# List of initialization scripts to execute
# Add or remove scripts as needed
INIT_SCRIPTS="
/usr/bin/insert-dtbo.sh \
/usr/bin/netwk-setup.sh \
"

# Execute each script in sequence
for script in $INIT_SCRIPTS; do
	if [ -f "$script" ]; then
		echo "Executing $script..." > /dev/console
		"$script" || {
			echo "ERROR: Failed to execute $script" > /dev/console
			exit 1
		}
	else
		echo "WARNING: Script $script not found, skipping..." > /dev/console
	fi
done

echo "##---Low-level initialization complete---" > /dev/console
exit 0
