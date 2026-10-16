#!/bin/zsh
# Finder entry point: Terminal stays open so progress and errors remain visible.
cd "${0:A:h}" || exit 1
/bin/zsh scripts/install.sh "$@"
INSTALL_RESULT=$?
print ""
read -r "?안내를 마치려면 Return을 누르세요. 이후 이 창을 닫아도 됩니다. " || true
exit "$INSTALL_RESULT"
