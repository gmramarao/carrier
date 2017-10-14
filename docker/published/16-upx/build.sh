#!/bin/sh
tar -xf upx-master.tar.xz
cd upx-master

# change the script interpreter to /bin/sh
sed -i -E 's/#!.*/#!\/bin\/sh/g' src/stub/scripts/check_whitespace.sh

# Calculates the optimal job count
JOBS=$(cat /proc/cpuinfo | grep processor | wc -l)

CXXFLAGS='-O3 -s -static' make -j $JOBS all CHECK_WHITESPACE=/bin/true

mkdir -p /tmp/install/bin

mv src/upx.out /tmp/install/bin/upx

# make a test by acking upx itself
/tmp/install/bin/upx --brute /tmp/install/bin/upx
