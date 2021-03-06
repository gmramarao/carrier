#!/bin/sh
# the repository name must exist in the environment
if [ -z $REPOSITORY ]; then
  echo 'Missing repository name...exiting...'
  exit 1
fi

# extract sources and prepare for build
tar -xf master.tar.gz
cd vim-master

PREFIX=/usr/local

CFLAGS='-O3 -s' \
  LDFLAGS='-Wl,-rpath,/usr/local/lib/,-rpath-link,/usr/local/lib/' \
  LUA_PREFIX=$PREFIX \
  ./configure \
    --prefix=$PREFIX \
    --with-features=huge \
    --enable-pythoninterp=dynamic \
    --enable-luainterp=yes \
    --enable-fail-if-missing \
    --enable-gui=no \
    --disable-nls \
    --without-x \
    --enable-multibyte \
    --with-compiledby='metabarj0'

# Calculates the optimal job count
JOBS=$(cat /proc/cpuinfo | grep processor | wc -l)

make -j $JOBS && make install

# make this image a package
packageIncluding \
  /usr/local/bin/entrypoint.sh \
  /usr/local/share/terminfo \
  metabarj0/python2 \
  metabarj0/lua
