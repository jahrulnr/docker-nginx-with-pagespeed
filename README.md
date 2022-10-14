![Docker badge](https://github.com/PMET-public/docker-nginx-with-pagespeed/workflows/build%20and%20publish%20to%20Docker%20Hub/badge.svg?branch=master)

# docker-nginx-with-pagespeed

Using the [offical nginx](https://hub.docker.com/_/nginx) as a baseimage, this image adds a few useful features/optimizations:

* [Pagespeed](https://www.modpagespeed.com/doc/build_ngx_pagespeed_from_source) to act as a CDN / web optimizer
* a self-signed cert and insecure private key for testing `/etc/ssl/certs/self.[key,crt]`
* a preconfigured reverse proxy template that interpolates the `PROXY_PASS` and `SERVER_NAME` env vars
* multi-stage build process to keep the image slim

If `SERVER_NAME` is specified, only that name will be proxied, and other domains will receive a 444 response. If it's not specified, any domain will be forwarded to `PROXY_PASS`.

Examples:

1. A secure, optimized reverse proxy using pagespeed to another docker service. Remeber to allow insecure localhost. It will vary by browser, but try [chrome://flags/#allow-insecure-localhost](chrome://flags/#allow-insecure-localhost) for chrome or `--ignore-certificate-errors` in headless mode.

```
docker run -e PROXY_PASS=http://host.docker.internal:3000 -p 443:443 pmetpublic/nginx-with-pagespeed
```

2. A simple, optimized web server using pagespeed with your own conf (same options as the offical `nginx`)
```
docker run -v /your-nginx.conf:/etc/nginx/conf.d/your-nginx.conf \
  -v /your-certs:/etc/ssl/certs \
  -p 443:443 \
  pmetpublic/nginx-with-pagespeed
```

3. As a docker compose service:
```
  proxy:
    image: pmet-public/nginx-with-pagespeed:1.1
    container_name: ps-proxy
    environment:
      - PROXY_PASS
      - SERVER_NAME
    ports:
      - '$LISTENING_PORT:443'
    volumes:
      - $FULLCHAIN_PATH:/etc/ssl/certs/self.crt
      - $PRIVKEY_PATH:/etc/ssl/certs/self.key
```
where your `.env` file might look like:
```
PROXY_PASS=http://my-service-container:8080
SERVER_NAME=my-domain.com
LISTENING_PORT=443
FULLCHAIN_PATH=/etc/letsencrypt/live/my-domain.com/fullchain.pem
PRIVKEY_PATH=/etc/letsencrypt/live/my-domain.com/privkey.pem
```
