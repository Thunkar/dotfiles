#!/usr/bin/env bash
# aur-review.sh <package> — inspect an AUR package before (re)pinning it in
# aur.txt.
#
# Clones the package's AUR git repo into a temp dir, prints its recent commit
# history (watch for maintainer changes), shows the diff since the currently
# pinned commit (if any), pages through PKGBUILD + any .install hooks, and
# finally prints the exact line to put in aur.txt. Nothing is built.
set -euo pipefail

pkg="${1:?usage: $0 <aur-package>}"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "▸ cloning https://aur.archlinux.org/$pkg.git"
git clone --quiet "https://aur.archlinux.org/$pkg.git" "$tmp/$pkg"
if [[ ! -f "$tmp/$pkg/PKGBUILD" ]]; then
    echo "!  no PKGBUILD — '$pkg' does not exist in the AUR (check the name)" >&2
    exit 1
fi
cd "$tmp/$pkg"

head="$(git rev-parse HEAD)"
pinned="$(awk -v p="$pkg" '$1 == p { print $2 }' "$DOTFILES_DIR/aur.txt" 2>/dev/null | head -1 || true)"

echo
echo "▸ $pkg — AUR HEAD $head"
echo "  page: https://aur.archlinux.org/packages/$pkg"
echo
echo "▸ recent AUR history (author changes = new maintainer, look twice):"
git log --format='  %h  %ad  %an  %s' --date=short -n 10
echo

if [[ -n "$pinned" ]]; then
    if [[ "$pinned" == "$head" ]]; then
        echo "▸ aur.txt pins $pinned — unchanged since your review."
    elif git cat-file -e "$pinned" 2>/dev/null; then
        echo "▸ changes since the pinned $pinned:"
        git --no-pager diff "$pinned" HEAD -- .
    else
        echo "!  pinned commit $pinned is NOT in the AUR history any more (history rewritten?) — read everything below carefully"
    fi
    echo
fi

echo "▸ opening PKGBUILD + install hooks in \${PAGER:-less}…"
files=(PKGBUILD)
while IFS= read -r -d '' f; do files+=("$f"); done < <(find . -maxdepth 1 -name '*.install' -print0)
"${PAGER:-less}" "${files[@]}"

echo
echo "Sources declared (anything with SKIP / a VCS URL is not checksum-pinned):"
grep -E '^\s*(source|sha256sums|sha512sums|b2sums)' .SRCINFO 2>/dev/null | sed 's/^/  /' || true
echo
echo "If it looks right, put this line in aur.txt (replacing any existing $pkg line):"
echo
echo "    $pkg $head"
echo
