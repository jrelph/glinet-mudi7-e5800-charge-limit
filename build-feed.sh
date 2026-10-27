#!/bin/sh
# Rebuilds both packages into feed/ and regenerates Packages + Packages.gz
set -e
cd "$(dirname "$0")"
rm -f feed/*.ipk
sh chargelimit/build-ipk.sh "$PWD/feed"
sh stockticker/build-ipk.sh "$PWD/feed"
cd feed
: > Packages
for f in *.ipk; do
	tar xzOf "$f" ./control.tar.gz | tar xzO ./control >> Packages
	printf 'Filename: %s\nSize: %s\nSHA256sum: %s\n\n' "$f" "$(wc -c < "$f" | tr -d ' ')" "$(shasum -a 256 "$f" | cut -d' ' -f1)" >> Packages
done
gzip -9nc Packages > Packages.gz
cat Packages
