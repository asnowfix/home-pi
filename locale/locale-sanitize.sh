#!/bin/sh
# macOS terminals send LC_CTYPE=UTF-8 (no language prefix) via SSH, which is
# invalid on Linux and causes perl/ls to fall back to C locale. Unset it so
# the system LANG takes effect instead.
if [ "${LC_CTYPE}" = "UTF-8" ]; then
    unset LC_CTYPE
fi
