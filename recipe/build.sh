#!/bin/bash

_rpcgen_hack_dir=""
if [[ $target_platform == linux-64 ]]; then
    _rpcgen_hack_dir=$SRC_DIR/rpcgen_hack
    mkdir -p $_rpcgen_hack_dir/bin
    cat <<EOF > ${_rpcgen_hack_dir}/bin/rpcgen
#!/bin/bash
$(patchelf --print-interpreter $CPP) $($CXX --print-sysroot)/usr/bin/rpcgen -Y ${_rpcgen_hack_dir}/bin \$@
EOF
    ln -s $(readlink -f ${CPP}) ${_rpcgen_hack_dir}/bin/cpp
    chmod +x ${_rpcgen_hack_dir}/bin/{rpcgen,cpp}
fi

declare -a _xtra_cmake_args
if [[ $target_platform == osx-64 ]]; then
    _xtra_cmake_args+=(-DWITH_ROUTER=OFF)
fi

cmake -S$SRC_DIR -Bbuild -GNinja \
  -DCMAKE_CXX_STANDARD=14 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="${_rpcgen_hack_dir};$PREFIX" \
  -DCOMPILATION_COMMENT=conda-forge \
  -DCMAKE_FIND_FRAMEWORK=LAST \
  -DWITH_UNIT_TESTS=OFF \
  -DWITH_SASL=system \
  -DWITH_ZLIB=system \
  -DWITH_ZSTD=system \
  -DWITH_LZ4=system \
  -DWITH_ICU=system \
  -DWITH_EDITLINE=system \
  -DWITH_PROTOBUF=system \
  -DWITH_LIBEVENT=system \
  -DWITH_BOOST=$SRC_DIR/boost \
  -DDEFAULT_CHARSET=utf8 \
  -DDEFAULT_COLLATION=utf8_general_ci \
  -DINSTALL_INCLUDEDIR=include/mysql \
  -DINSTALL_MANDIR=share/man \
  -DINSTALL_DOCDIR=share/doc/mysql \
  -DINSTALL_DOCREADMEDIR=mysql \
  -DINSTALL_INFODIR=share/info \
  -DCMAKE_INSTALL_PREFIX=$PREFIX \
  -DINSTALL_MYSQLSHAREDIR=share/mysql \
  -DINSTALL_SUPPORTFILESDIR=mysql/support-files \
  "${_xtra_cmake_args[@]}"

cmake --build build
