#!/bin/sh
# Run from your computer:  ./install-remote.sh [router-ip]   (needs SSH as root)
IP=${1:?usage: ./install-remote.sh <router-ip>}
D=$(cd "$(dirname "$0")" && pwd)
tar czf /tmp/glcl.tgz -C "$D" install.sh uninstall.sh files || exit 1
scp -O /tmp/glcl.tgz root@$IP:/tmp/ && ssh root@$IP 'rm -rf /tmp/glcl && mkdir /tmp/glcl && tar xzf /tmp/glcl.tgz -C /tmp/glcl && sh /tmp/glcl/install.sh'
