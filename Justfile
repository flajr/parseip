default:
    @just --list --unsorted

host := `uname -a`

# used for building pcre...
export CC := "musl-gcc -static"

project     := "parseip"
main_file   := project + ".nim"
main_exec   := project
musl_exec   := project + "_x86_64-unknown-linux-musl"

pcre_ver    := "8.45"
pcre_name   := "pcre-" + pcre_ver
pcre_tar    := pcre_name + ".tar.gz"
pcre_get    := "https://downloads.sourceforge.net/pcre/" + pcre_tar
pcre_dir    := justfile_directory() + "/pcre"

zlib_ver    := "1.2.11"
zlib_name   := "zlib-" + zlib_ver
zlib_tar    := zlib_name + ".tar.gz"
zlib_get    := "https://www.zlib.net/" + zlib_tar
zlib_dir    := justfile_directory() + "/zlib"
# invocation_directory()
# justfile_directory()

alias b := build

# build main
# Garbage Collector and Memory management https://nim-lang.org/docs/mm.html
# --mm:markAndSweep \
# --mm:arc \
build:
	nim compile {{project}}

# run a specific test
# test TEST: build
#     ./test --test {{TEST}}

# download and compile pcre 8.45
pcre_get:
    [ ! -e "{{pcre_tar}}" ] && curl -sLO "{{pcre_get}}" || true
    [ ! -e "{{pcre_name}}" ] && tar -xf "{{pcre_tar}}" -C "{{justfile_directory()}}" || true

# compile pcre
pcre: pcre_get
    cd {{pcre_name}} && ./configure \
    --prefix="{{pcre_dir}}" \
    --enable-jit \
    --enable-unicode-properties \
    --enable-pcre16 \
    --enable-pcre32 \
    --disable-shared
    cd {{pcre_name}} && make -j8 && make install

zlib_get:
    [ ! -e "{{zlib_tar}}" ] && curl -sLO "{{zlib_get}}" || true
    [ ! -e "{{zlib_name}}" ] && tar -xf "{{zlib_tar}}" -C "{{justfile_directory()}}" || true

zlib: zlib_get
    cd {{zlib_name}} && ./configure \
    --prefix="{{zlib_dir}}"
    cd {{zlib_name}} && make -j8 && make install

shasum:
    sha256sum {{main_exec}} >{{main_exec}}.sha256

release tag:
    gh release create {{tag}}
