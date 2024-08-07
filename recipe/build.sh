#! /bin/bash
set -ex

for subdir in ./cextern/healpix/src/common_libraries/libsharp ./cextern/healpix/src/cxx; do
    pushd $subdir
    # Get an updated config.sub and config.guess
    cp $BUILD_PREFIX/share/libtool/build-aux/config.* ./
    ./configure --prefix="${PREFIX}"
    make install
    popd
done

# Make sure that Cython-generated files are always generated by our
# own Cython. Motivated by https://github.com/healpy/healpy/issues/473 .

cython_files="
healpy/src/_query_disc.cpp
healpy/src/_sphtools.cpp
healpy/src/_pixelfunc.cpp
"

rm -f $cython_files

# Now we can proceed as usual.

exec $PYTHON -m pip install . --no-deps --ignore-installed --no-cache-dir -vvv
