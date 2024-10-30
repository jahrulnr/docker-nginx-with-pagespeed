ARG NGINX_VERSION=1.26.2

FROM nginx:$NGINX_VERSION as builder
ARG TARGETARCH
COPY incubator-pagespeed-mod-aarch64.patch /
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOF

  apt-get update && apt-get upgrade -y
  apt-get install -y sudo vim curl build-essential zlib1g-dev libpcre3-dev unzip wget uuid-dev libssl-dev git python gperf rsync

  # get the nginx pagespeed module source used by later steps
  git clone https://github.com/apache/incubator-pagespeed-ngx.git

  # build or download the PageSpeed Optimization Libraries (PSOL) based on arch
  if [ "$TARGETARCH" = "arm64" ]; then

    # build and configure PSOL for arm64
    git clone https://github.com/apache/incubator-pagespeed-mod.git
    cd incubator-pagespeed-mod
    git reset --hard
    git checkout 409bd76fd6eafc4cf1c414e679f3e912447a6a31
    git submodule update --init --recursive
    patch -Np1 -i ../incubator-pagespeed-mod-aarch64.patch
    install/build_psol.sh --skip_tests --skip_deps
    cd /incubator-pagespeed-ngx
    cp /incubator-pagespeed-mod/psol-1.15.0.0-aarch64.tar.gz .
    tar xvf psol-1.15.0.0-aarch64.tar.gz
    sed -i 's/x86_64/aarch64/' config
    sed -i 's/x64/aarch64/' config
    sed -i 's/-luuid/-l:libuuid.so.1/' config

  elif [ "$TARGETARCH" = "amd64" ]; then

    # download PSOL for amd64
    curl -o /tmp/install-pagespeed.sh -f -L -sS https://ngxpagespeed.com/install
    chmod +x /tmp/install-pagespeed.sh
    /tmp/install-pagespeed.sh -y \
      --ngx-pagespeed-version latest-beta \
      --dynamic-module
    cd /incubator-pagespeed-ngx
    mv /root/incubator-pagespeed-ngx-latest-beta/psol .

  else

    echo "Architecture not supported." && exit 1

  fi

  # build dynamic nginx pagespeed module
  cd /
  wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz
  tar xvf nginx-$NGINX_VERSION.tar.gz
  cd nginx-$NGINX_VERSION
  ./configure --add-dynamic-module=/incubator-pagespeed-ngx --with-compat
  make

  # create a self-signed key for convenience
  openssl req  -nodes -new -x509  -keyout /etc/ssl/certs/self.key -out /etc/ssl/certs/self.crt -subj '/CN=self'

EOF

FROM nginx:$NGINX_VERSION as final
ARG NGINX_VERSION
COPY --from=builder /nginx-$NGINX_VERSION/objs/ngx_pagespeed.so /usr/lib/nginx/modules/
COPY --from=builder /etc/ssl/certs /etc/ssl/certs
# nginx.conf based on https://github.com/apache/incubator-pagespeed-ngx/issues/1213
COPY nginx.conf /etc/nginx/nginx.conf
COPY rev-proxy.conf.template /etc/nginx/templates/
ENV PROXY_PASS "http://127.0.0.1:8080"
ENV SERVER_NAME "~^.*\$"
