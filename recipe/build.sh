#!/bin/bash

# this script is based off the homebrew package:
# https://github.com/Homebrew/homebrew-core/blob/master/Formula/mysql.rb

mkdir -p build
cd build

declare -a _cmake_config_extra
if [[ ${HOST} =~ .*darwin.* ]]; then
  _cmake_config_extra+=(-DCMAKE_OSX_SYSROOT=${CONDA_BUILD_SYSROOT})
elif [[ ${HOST} =~ .*linux.* ]]; then
  # Force -std=gnu++98 to workaround attempt to create a reference to a reference
  # in rapid/plugin/group_replication/libmysqlgcs/src/bindings/xcom/gcs_xcom_communication_interface.cc (line 202)
  re='(.*[[:space:]])\-std\=[^[:space:]]*(.*)'
  if [[ "${CXXFLAGS}" =~ $re ]]; then
    CXXFLAGS="${BASH_REMATCH[1]}-std=gnu++98${BASH_REMATCH[2]}"
  fi
  # https://gcc.gnu.org/bugzilla/show_bug.cgi?id=82956
  if [[ ${HOST} =~ .*x86_64.* ]]; then
    re='(.*)-fvisibility-inlines-hidden(.*)'
    if [[ "${CXXFLAGS}" =~ $re ]]; then
      CXXFLAGS="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    fi
  fi
  export LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
  _cmake_config_extra+=(-DRPC_INCLUDE_DIR="${BUILD_PREFIX}/${HOST}/sysroot/usr/include")
  # The ideal situation would be to have libtirpc and rpcsvc-proto as conda packages
  # Since our rpcgen has an interpreter which is not the host's program interpreter ...
  # -bash: .//dev/x86_64-conda_cos6-linux-gnu/sysroot/usr/bin/rpcgen:
  # /lib/ld-linux-x86-64.so.2: bad ELF interpreter: No such file or directory
  # ... we need this really nasty hack:
  ln -s $CPP $BUILD_PREFIX/bin/cpp
  cat <<'EOF' > $BUILD_PREFIX/bin/rpcgen
#!/bin/bash
$(patchelf --print-interpreter /proc/self/exe) ${BUILD_PREFIX}/${HOST}/sysroot/usr/bin/rpcgen -Y $BUILD_PREFIX/bin/ "$@"
EOF
  chmod +x $BUILD_PREFIX/bin/rpcgen

fi
LDFLAGS="${LDFLAGS} -Wl,-rpath,${PREFIX}/lib"
CXXFLAGS="${CXXFLAGS} -fno-strict-aliasing"
CFLAGS="${CFLAGS} -fno-strict-aliasing"

# -DINSTALL_* are relative to -DCMAKE_INSTALL_PREFIX
mkdir -p ${PREFIX}/mysql
cmake \
    -DCMAKE_PREFIX_PATH=${PREFIX} \
    -DCMAKE_INSTALL_PREFIX=${PREFIX} \
    -DINSTALL_INCLUDEDIR=include/mysql \
    -DINSTALL_MANDIR=share/man \
    -DINSTALL_DOCDIR=share/doc/mysql \
    -DINSTALL_DOCREADMEDIR=mysql \
    -DINSTALL_INFODIR=share/info \
    -DINSTALL_MYSQLSHAREDIR=share/mysql \
    -DINSTALL_SUPPORTFILESDIR=mysql/support-files \
    -DINSTALL_SCRIPTDIR=mysql/scripts \
    -DCMAKE_CXX=${CXX} \
    -DCMAKE_CC=${CC} \
    -DCMAKE_AR=${AR} \
    -DCMAKE_RANLIB=${RANLIB} \
    -DCMAKE_LINKER=${LD} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_FIND_FRAMEWORK=LAST \
    -DCMAKE_VERBOSE_MAKEFILE=OFF \
    -DWITH_UNIT_TESTS=OFF \
    -DDEFAULT_CHARSET=utf8 \
    -DDEFAULT_COLLATION=utf8_general_ci \
    -DCOMPILATION_COMMENT=conda-forge \
    -DWITH_SSL=system \
    -DWITH_EDITLINE=system \
    -DDOWNLOAD_BOOST=1 -DWITH_BOOST=${SRC_DIR}/boost \
    ${_cmake_config_extra[@]} \
    .. 2>&1 | tee cmake.log

make -j${CPU_COUNT} ${VERBOSE_CM} 2>&1 | tee build.log
make install ${VERBOSE_CM} 2>&1 | tee install.log

# remove this dir so we do not ship it
cd ${PREFIX}/mysql-test
mysql_temp_dir=`mktemp -d ${TMPDIR}/tmp/XXXXXXXXXXXX`
{
    set -e
    # the || here is a rough try...except
    perl mysql-test-run.pl status --vardir=${mysql_temp_dir} || rm -rf ${mysql_temp_dir}
}
cd -
# always delete anything left
rm -rf ${mysql_temp_dir}
rm -rf ${PREFIX}/mysql-test

# Make a symlink to script to start the server directly.
ln -s ${PREFIX}/mysql/support-files/mysql.server ${PREFIX}/bin/mysql.server
