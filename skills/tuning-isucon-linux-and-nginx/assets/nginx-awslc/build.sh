#!/usr/bin/env bash
# nginx 1.28 + AWS-LC (pcre2 / zlib / AWS-LC を静的リンク) をビルドする。
# 既定は配布用: x86-64-v2 + glibc 2.35 (Ubuntu 22.04 以降で動く) を zig cc で作る。
#   OUT=dist/nginx-awslc ./build.sh          # 配布用 (zig が必要)
#   PORTABLE=0 MARCH=native ./build.sh       # その場のホスト専用 (gcc)
# パッチ (patches/*.py) の中身は ../../references/NGINX-AWSLC.md を参照。
set -euo pipefail
D=$(cd "$(dirname "$0")" && pwd)
NGINX_V=${NGINX_V:-1.28.0}
PCRE2_V=${PCRE2_V:-10.44}
ZLIB_V=${ZLIB_V:-1.3.1}
AWSLC_V=${AWSLC_V:-v1.62.0}
PORTABLE=${PORTABLE:-1}
MARCH=${MARCH:-x86-64-v2}
GLIBC=${GLIBC:-2.35}
W=${WORK:-$D/.build}
OUT=${OUT:-$D/dist/nginx-awslc}

if [[ $PORTABLE == 1 ]]; then
  ZIG=${ZIG:-$(command -v zig || true)}
  [ -n "$ZIG" ] && "$ZIG" version >/dev/null 2>&1 || { echo "zig not usable (ZIG=/path/to/zig か PORTABLE=0 で gcc ビルド)" >&2; exit 1; }
  mkdir -p "$W/bin"
  # configure / cmake が 1 語のコンパイラを期待するのでラッパを置く。
  # zig cc は -O0 のコードに UBSan を入れるので -fno-sanitize=undefined。-Wp,<arg> も受け付けないので、-Wp,-U/-D を素の -U/-D に直す (AWS-LC の jitterentropy が使う)
  for t in cc c++; do
    cat >| "$W/bin/$t" <<WRAP
#!/usr/bin/env bash
a=()
for x in "\$@"; do
  case \$x in -Wp,-U*|-Wp,-D*) a+=("\${x#-Wp,}") ;; *) a+=("\$x") ;; esac
done
exec "$ZIG" $t -target x86_64-linux-gnu.$GLIBC -fno-sanitize=undefined "\${a[@]}"
WRAP
  done
  chmod +x "$W/bin/cc" "$W/bin/c++"
  CC=$W/bin/cc CXX=$W/bin/c++
  MARCH=${MARCH//-/_}   # zig の CPU 名は x86_64_v2 形式
else
  CC=${CC:-/usr/bin/gcc} CXX=${CXX:-/usr/bin/g++}
fi

mkdir -p "$W" "$(dirname "$OUT")"
cd "$W"
[ -d nginx-$NGINX_V ] || curl -fsSL https://nginx.org/download/nginx-$NGINX_V.tar.gz | tar xz
[ -d pcre2-$PCRE2_V ] || curl -fsSL https://github.com/PCRE2Project/pcre2/releases/download/pcre2-$PCRE2_V/pcre2-$PCRE2_V.tar.gz | tar xz
[ -d zlib-$ZLIB_V ] || curl -fsSL https://zlib.net/fossils/zlib-$ZLIB_V.tar.gz | tar xz
[ -d aws-lc ] || git clone -q --depth 1 --branch "$AWSLC_V" https://github.com/aws/aws-lc.git

python3 "$D/patches/awslc-sock-no-soerror.patch.py" "$PWD/aws-lc"
python3 "$D/patches/awslc-sock-short-read-flag.patch.py" "$PWD/aws-lc"
cmake -S aws-lc -B aws-lc/build -GNinja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTING=OFF -DDISABLE_GO=ON -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_C_FLAGS="-march=$MARCH -ffile-prefix-map=$W=/build" \
  -DCMAKE_CXX_FLAGS="-ffile-prefix-map=$W=/build" >/dev/null
ninja -C aws-lc/build ssl crypto >| "$W/aws-lc-build.log" 2>&1 || { grep -E "error|FAILED" "$W/aws-lc-build.log" | head -20 || true; exit 1; }
A=$PWD/aws-lc

cd nginx-$NGINX_V
# AWS-LC には SSL_SESSION_get0_hostname が無い (BoringSSL と同じ扱いにする)
grep -q OPENSSL_IS_AWSLC src/http/ngx_http_request.c || sed -i \
  's/     \&\& !defined LIBRESSL_VERSION_NUMBER \&\& !defined OPENSSL_IS_BORINGSSL)/     \&\& !defined LIBRESSL_VERSION_NUMBER \&\& !defined OPENSSL_IS_BORINGSSL \&\& !defined OPENSSL_IS_AWSLC)/' \
  src/http/ngx_http_request.c
python3 "$D/patches/nginx-incoming-cpu.patch.py" "$PWD"
python3 "$D/patches/nginx-upstream-cached-no-soerror.patch.py" "$PWD"
python3 "$D/patches/nginx-ssl-recv-short-read.patch.py" "$PWD"
# Ubuntu パッケージの nginx と同じパス (設定・ログ・一時ディレクトリをそのまま使える)
CC=$CC ./configure --prefix=/usr/share/nginx --sbin-path=/usr/local/sbin/nginx-awslc \
  --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log --pid-path=/run/nginx.pid --lock-path=/var/lock/nginx.lock \
  --modules-path=/usr/lib/nginx/modules --http-client-body-temp-path=/var/lib/nginx/body \
  --http-fastcgi-temp-path=/var/lib/nginx/fastcgi --http-proxy-temp-path=/var/lib/nginx/proxy \
  --http-scgi-temp-path=/var/lib/nginx/scgi --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
  --with-threads --with-http_ssl_module --with-http_v2_module --with-http_gzip_static_module \
  --with-http_stub_status_module --with-http_realip_module \
  --without-http_auth_basic_module \
  --with-pcre=../pcre2-$PCRE2_V --with-pcre-jit --with-zlib=../zlib-$ZLIB_V \
  --with-cc-opt="-O2 -march=$MARCH -ffile-prefix-map=$W=/build -I$A/include" \
  --with-ld-opt="-L$A/build/ssl -L$A/build/crypto -lstdc++ -lpthread" >/dev/null
# nginx -V に埋め込まれる configure 引数からビルド環境のパスを消す
sed -i "s|$W|/build|g" objs/ngx_auto_config.h
make -j"$(nproc)" >| "$W/nginx-build.log" 2>&1 || { grep -E "error|Error" "$W/nginx-build.log" | head -20 || true; exit 1; }
command cp -f objs/nginx "$OUT"
strip "$OUT" 2>/dev/null || true
echo "built $OUT"
"$OUT" -V 2>&1 | head -3
