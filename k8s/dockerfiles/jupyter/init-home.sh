#!/bin/bash
# before-notebook.d hook: restore home directory contents from the image backup.
# When a PVC is mounted on /home/jovyan, the image-layer contents are replaced
# by the (initially empty) volume. This script extracts the backup tar to
# populate the home directory on first startup.

file_path="${HOME}/.intdata"

if [ -f "$file_path" ]; then
    echo "Base data exists."
else
    echo "Base data does not exist, extracting home backup..."
    # Extract contents into home dir. The PVC mount point itself (/home/jovyan)
    # is owned by root and its mode cannot be changed by UID 1000, so we strip
    # the leading path component and extract directly into $HOME, ignoring any
    # permission errors on existing directories.
    tar -xf /tmp/basehome.tar -C "${HOME}" --strip-components=2 --no-same-owner --no-same-permissions 2>/dev/null || true
    echo "1" > "$file_path"
fi
