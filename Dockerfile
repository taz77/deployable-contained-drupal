ARG ALPINE_VER=3.11
ARG NGINX_VER=1.17.8
ARG APK_MAIN=http://dl-cdn.alpinelinux.org/alpine/v3.11/main
ARG APK_COMMUNITY=http://dl-cdn.alpinelinux.org/alpine/v3.11/community
ARG APK_EDGE=http://dl-3.alpinelinux.org/alpine/edge
ARG PHP_URL=https://www.php.net/get/php-7.4.3.tar.xz/from/this/mirror
ARG PHP_ASC_URL=https://www.php.net/get/php-7.4.3.tar.xz.asc/from/this/mirror

FROM alpine:${ALPINE_VER}
ARG ALPINE_DEV
ARG NGINX_VER
ARG APK_MAIN
ARG APK_COMMUNITY
ARG APK_EDGE
ARG PHP_URL
ARG PHP_ASC_URL

ENV NGINX_VER=${NGINX_VER} \
    APP_ROOT="/var/www/html" \
    FILES_DIR="/mnt/files" \
    NGINX_VHOST_PRESET="html" \
    APK_MAIN=${APK_MAIN} \
    APK_COMMUNITY=${APK_COMMUNITY} \
    APK_EDGE=${APK_EDGE} \
    PHP_URL=${PHP_URL} \
    PHP_ASC_URL=${PHP_ASC_URL}

ENV PHPIZE_DEPS \
		autoconf \
		dpkg-dev dpkg \
		file \
		g++ \
		gcc \
		libc-dev \
		make \
		pkgconf \
		re2c

COPY bin /usr/local/bin
COPY templates /etc/gotpl/
COPY docker-entrypoint.sh /

RUN echo $APK_MAIN > /etc/apk/repositories; \
    echo $APK_COMMUNITY >> /etc/apk/repositories;
    
RUN  set -xe; \
     apk add --update --no-cache -t .tools\
        bash \
        ca-certificates \
        curl \
        gzip \
        tar \
        unzip \
        wget \
        xz \
        openssl \
        libuuid \
        findutils \
        make \
        nghttp2 \
        sudo; \
    \
    \
    if [ -n "${ALPINE_DEV}" ]; then \
        apk add --update git coreutils jq sed gawk grep gnupg; \
    fi; \
    \
    gotpl_url="https://github.com/wodby/gotpl/releases/download/0.1.5/gotpl-alpine-linux-amd64-0.1.5.tar.gz"; \
    wget -qO- "${gotpl_url}" | tar xz -C /usr/local/bin; \
    \
    nginx_up_ver="0.9.1"; \
    ngx_pagespeed_ver="1.13.35.2"; \
    mod_pagespeed_ver="1.13.35.2"; \
    ngx_modsecurity_ver="1.0.0"; \
    modsecurity_ver="3.0.3"; \
    owasp_crs_ver="3.1.0"; \
    \
    addgroup -S nginx; \
    adduser -S -D -H -h /var/cache/nginx -s /sbin/nologin -G nginx nginx; \
    \
	addgroup -g 1000 -S joesmith; \
	adduser -u 1000 -D -S -s /bin/bash -G joesmith joesmith; \
	sed -i '/^joesmith/s/!/*/' /etc/shadow; \
	echo "PS1='\w\$ '" >> /home/joesmith/.bashrc; \
    \
    apk add --update --no-cache -t .nginx-build-deps \
        apr-dev \
        apr-util-dev \
        build-base \
        gd-dev \
        git \
        gnupg \
        gperf \
        icu-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libressl-dev \
        libtool \
        libxslt-dev \
        linux-headers \
        pcre-dev \
        zlib-dev; \
     \
     apk add --no-cache -t .libmodsecurity-build-deps \
        autoconf \
        automake \
        bison \
        flex \
        g++ \
        git \
        libmaxminddb-dev \
        libstdc++ \
        libtool \
        libxml2-dev \
        pcre-dev \
        rsync \
        sed \
        yajl \
        yajl-dev; \
    \
    # @todo download from main repo when updated to alpine 3.10.
    apk add -U --no-cache -t .nginx-edge-build-deps -X ${APK_EDGE} brotli-dev; \
    # Modsecurity lib.
    cd /tmp; \
    git clone --depth 1 -b "v${modsecurity_ver}" --single-branch https://github.com/SpiderLabs/ModSecurity; \
    cd ModSecurity; \
    git submodule init;  \
    git submodule update; \
    ./build.sh; \
    ./configure --disable-doxygen-doc --disable-doxygen-html; \
    make -j$(getconf _NPROCESSORS_ONLN); \
    make install;  \
    mkdir -p /etc/nginx/modsecurity/; \
    mv modsecurity.conf-recommended /etc/nginx/modsecurity/recommended.conf;  \
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsecurity/recommended.conf; \
    cp unicode.mapping /etc/nginx/modsecurity/; \
    rsync -a --links /usr/local/modsecurity/lib/libmodsecurity.so* /usr/local/lib/; \
    \
    # Brotli.
    cd /tmp; \
    git clone --depth 1 --single-branch https://github.com/google/ngx_brotli; \
    \
    # Get ngx modsecurity module.
    mkdir -p /tmp/ngx_http_modsecurity_module; \
    ver="${ngx_modsecurity_ver}"; \
    url="https://github.com/SpiderLabs/ModSecurity-nginx/releases/download/v${ver}/modsecurity-nginx-v${ver}.tar.gz"; \
    wget -qO- "${url}" | tar xz --strip-components=1 -C /tmp/ngx_http_modsecurity_module; \
    \
    # OWASP.
    wget -qO- "https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v${owasp_crs_ver}.tar.gz" | tar xz -C /tmp; \
    cd /tmp/owasp-modsecurity-crs-*; \
    sed -i "s#SecRule REQUEST_COOKIES|#SecRule REQUEST_URI|REQUEST_COOKIES|#" rules/REQUEST-941-APPLICATION-ATTACK-XSS.conf; \
    mkdir -p /etc/nginx/modsecurity/crs/; \
    mv crs-setup.conf.example /etc/nginx/modsecurity/crs/setup.conf; \
    mv rules /etc/nginx/modsecurity/crs; \
    \
    # Pagespeed is not compatible with the latest release of Alpine and Alpine is still not officially supported. Follow
    # this issue for updates: https://github.com/apache/incubator-pagespeed-ngx/issues/1181
    # Get ngx pagespeed module.
    # git clone -b "v${ngx_pagespeed_ver}-stable" \
    #       --recurse-submodules \
    #       --shallow-submodules \
    #       --depth=1 \
    #       -c advice.detachedHead=false \
    #       -j$(getconf _NPROCESSORS_ONLN) \
    #       https://github.com/apache/incubator-pagespeed-ngx.git \
    #       /tmp/ngx_pagespeed; \
    \
    # This PSOL from Wodby was compiled with Alpine 3.8 and will not load on Alpine 3.11.
    # url="https://github.com/wodby/nginx-alpine-psol/releases/download/${mod_pagespeed_ver}/psol.tar.gz"; \
    # wget -qO- "${url}" | tar xz -C /tmp/ngx_pagespeed; \
    \
    # Get ngx uploadprogress module.
    mkdir -p /tmp/ngx_http_uploadprogress_module; \
    url="https://github.com/masterzen/nginx-upload-progress-module/archive/v${nginx_up_ver}.tar.gz"; \
    wget -qO- "${url}" | tar xz --strip-components=1 -C /tmp/ngx_http_uploadprogress_module; \
    \
    # Download nginx.
    curl -fSL "https://nginx.org/download/nginx-${NGINX_VER}.tar.gz" -o /tmp/nginx.tar.gz; \
    curl -fSL "https://nginx.org/download/nginx-${NGINX_VER}.tar.gz.asc"  -o /tmp/nginx.tar.gz.asc; \
    GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 gpg_verify /tmp/nginx.tar.gz.asc /tmp/nginx.tar.gz; \
    tar zxf /tmp/nginx.tar.gz -C /tmp; \
    \
    cd "/tmp/nginx-${NGINX_VER}"; \
    ./configure \
        --prefix=/usr/share/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --pid-path=/var/run/nginx/nginx.pid \
        --lock-path=/var/run/nginx/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-compat \
        --with-file-aio \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
		--with-http_image_filter_module=dynamic \
        --with-http_mp4_module \
        --with-http_random_index_module \
        --with-http_realip_module \
        --with-http_secure_link_module \
		--with-http_slice_module \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_v2_module \
		--with-http_xslt_module=dynamic \
        --with-ipv6 \
        --with-ld-opt="-Wl,-z,relro,--start-group -lapr-1 -laprutil-1 -licudata -licuuc -lpng -lturbojpeg -ljpeg" \
        --with-mail \
        --with-mail_ssl_module \
        --with-pcre-jit \
        --with-stream \
        --with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-stream_realip_module \
        --with-threads \
        --add-module=/tmp/ngx_http_uploadprogress_module \
        --add-module=/tmp/ngx_brotli \
        # --add-dynamic-module=/tmp/ngx_pagespeed \
        --add-dynamic-module=/tmp/ngx_http_modsecurity_module; \
    \
    make -j$(getconf _NPROCESSORS_ONLN); \
    make install; \
    mkdir -p /usr/share/nginx/modules; \
    \
    install -g joesmith -o joesmith -d \
        "${APP_ROOT}" \
        "${FILES_DIR}" \
        /etc/nginx/conf.d \
        /var/cache/nginx \
        /var/lib/nginx; \
    \
    touch /etc/nginx/upstream.conf; \
    chown -R joesmith:joesmith /etc/nginx; \
    \
    install -g nginx -o nginx -d \
        /var/cache/ngx_pagespeed \
        /pagespeed_static \
        /ngx_pagespeed_beacon; \
    \
    install -m 400 -d /etc/nginx/pki; \
    strip /usr/sbin/nginx*; \
    strip /usr/lib/nginx/modules/*.so; \
    strip /usr/local/lib/libmodsecurity.so*; \
    \
    for i in /usr/lib/nginx/modules/*.so; do ln -s "${i}" /usr/share/nginx/modules/; done; \
    \
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' /usr/sbin/nginx /usr/local/modsecurity/lib/*.so /usr/lib/nginx/modules/*.so /tmp/envsubst \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-cache --virtual .nginx-rundeps $runDeps; \
    \
    # Script to fix volumes permissions via sudo.
    echo "find ${APP_ROOT} ${FILES_DIR} -maxdepth 0 -uid 0 -type d -exec chown joesmith:joesmith {} +" > /usr/local/bin/init_volumes; \
    chmod +x /usr/local/bin/init_volumes; \
    \
    { \
        echo -n 'joesmith ALL=(root) NOPASSWD:SETENV: ' ; \
        echo -n '/usr/local/bin/init_volumes, ' ; \
        echo '/usr/sbin/nginx' ; \
    } | tee /etc/sudoers.d/joesmith; \
    \
    chown joesmith:joesmith /usr/share/nginx/html/50x.html; \
    \
    apk del --purge .nginx-build-deps .nginx-edge-build-deps .libmodsecurity-build-deps; \
    rm -rf \
        /tmp/* \
        /usr/local/modsecurity \
        /var/cache/apk/* ; \
    ############################
    # Begin PHP installation.  #
    ############################
    apk add --update --no-cache -t .depdrup-php-run-deps \
        c-client=2007f-r11 \
        fcgi \
        findutils \
        freetype=2.10.1-r0 \
        git \
        gmp=6.1.2-r1 \
        icu-libs=64.2-r0 \
        imagemagick=7.0.9.7-r0 \
        jpegoptim=1.4.6-r0 \
        less \
        libbz2=1.0.8-r1 \
        libevent=2.1.11-r0 \
        libjpeg-turbo=2.0.4-r0 \
        libjpeg-turbo-utils \
        libldap=2.4.48-r1 \
        libltdl=2.4.6-r7 \
        libmemcached-libs=1.0.18-r4 \
        libmcrypt=2.5.8-r7 \
        libpng=1.6.37-r1 \
        librdkafka=1.2.2-r0 \
        libuuid=2.34-r1 \
        libwebp=1.0.3-r0 \
        libxslt=1.1.34-r0 \
        libzip=1.5.2-r0 \
        make \
        mariadb-client \
        nano \
        openssh \
        openssh-client \
        patch \
	    pngquant \
        postgresql-client \
        rabbitmq-c=0.10.0-r0 \
        rsync \
        su-exec \
        sudo \
        tidyhtml-libs=5.6.0-r0 \
        # todo: move out tig and tmux to -dev version.
        tig \
        tmux \
        yaml=0.2.2-r1; \
    \
    apk add --update --no-cache -t .depdrup-php-build-deps \
        autoconf \
        cmake \
        build-base \
        bzip2-dev \
        freetype-dev \
        gmp-dev \
        icu-dev \
        imagemagick-dev \
        imap-dev \
        jpeg-dev \
        krb5-dev \
        libevent-dev \
        libgcrypt-dev \
        libjpeg-turbo-dev \
        libmemcached-dev \
        libmcrypt-dev \
        libpng-dev \
        librdkafka-dev \
        libtool \
        libwebp-dev \
        libxslt-dev \
        libzip-dev \
        openldap-dev \
        openssl-dev \
        pcre-dev \
        postgresql-dev \
        rabbitmq-c-dev \
        tidyhtml-dev \
        yaml-dev;

# Ensure www-data user exists.
RUN set -eux; \
	addgroup -g 82 -S www-data; \
	adduser -u 82 -D -S -G www-data www-data
    # 82 is the standard uid/gid for "www-data" in Alpine.


ENV PHP_INI_DIR /usr/local/etc/php
RUN set -eux; \
	mkdir -p "$PHP_INI_DIR/conf.d";  \
    chown www-data:www-data /var/www/html; \
	chmod 777 /var/www/html

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# Adds GNU HASH segments to generated executables (this is used if present, and is much faster than sysv hash; in this configuration, sysv hash is also generated)
# https://github.com/docker-library/php/issues/272
# -D_LARGEFILE_SOURCE and -D_FILE_OFFSET_BITS=64 (https://www.php.net/manual/en/intro.filesystem.php)
ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"
ENV PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"

ENV GPG_KEYS 42670A7FE4D0441C8E4632349E4FDC074A4EF02D 5A52880781F755608BF815FC910DEB46F53EA312

ENV PHP_VERSION 7.4.3
ENV PHP_SHA256="cf1f856d877c268124ded1ede40c9fb6142b125fdaafdc54f855120b8bc6982a" PHP_MD5=""
COPY docker-php-source /usr/local/bin/

RUN set -eux; \
	\
	apk add --no-cache --virtual .fetch-deps gnupg; \
	\
	mkdir -p /usr/src; \
	cd /usr/src; \
	\
	curl -fsSL -o php.tar.xz "$PHP_URL"; \
	\
	if [ -n "$PHP_SHA256" ]; then \
		echo "$PHP_SHA256 *php.tar.xz" | sha256sum -c -; \
	fi; \
	if [ -n "$PHP_MD5" ]; then \
		echo "$PHP_MD5 *php.tar.xz" | md5sum -c -; \
	fi; \
	\
	if [ -n "$PHP_ASC_URL" ]; then \
		curl -fsSL -o php.tar.xz.asc "$PHP_ASC_URL"; \
		export GNUPGHOME="$(mktemp -d)"; \
		for key in $GPG_KEYS; do \
			gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
		done; \
		gpg --batch --verify php.tar.xz.asc php.tar.xz; \
		gpgconf --kill all; \
		rm -rf "$GNUPGHOME"; \
	fi; \
	\
	apk del --no-network .fetch-deps; \
    \
    apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		argon2-dev \
		coreutils \
		curl-dev \
		libedit-dev \
		libsodium-dev \
		libxml2-dev \
		linux-headers \
		oniguruma-dev \
		openssl-dev \
		sqlite-dev \
	; \
	\
	export CFLAGS="$PHP_CFLAGS" \
		CPPFLAGS="$PHP_CPPFLAGS" \
		LDFLAGS="$PHP_LDFLAGS" \
	; \
	docker-php-source extract; \
	cd /usr/src/php; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	./configure \
		--build="$gnuArch" \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		\
# make sure invalid --configure-flags are fatal errors intead of just warnings
		--enable-option-checking=fatal \
		\
# https://github.com/docker-library/php/issues/439
		--with-mhash \
		\
# --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
		--enable-ftp \
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
		--enable-mbstring \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
		--enable-mysqlnd \
# https://wiki.php.net/rfc/argon2_password_hash (7.2+)
		--with-password-argon2 \
# https://wiki.php.net/rfc/libsodium
		--with-sodium=shared \
# always build against system sqlite3 (https://github.com/php/php-src/commit/6083a387a81dbbd66d6316a3a12a63f06d5f7109)
		--with-pdo-sqlite=/usr \
		--with-sqlite3=/usr \
		\
		--with-curl \
		--with-libedit \
		--with-openssl \
		--with-zlib \
		\
# in PHP 7.4+, the pecl/pear installers are officially deprecated (requiring an explicit "--with-pear") and will be removed in PHP 8+; see also https://github.com/docker-library/php/issues/846#issuecomment-505638494
		--with-pear \
		\
# bundled pcre does not support JIT on s390x
# https://manpages.debian.org/stretch/libpcre3-dev/pcrejit.3.en.html#AVAILABILITY_OF_JIT_SUPPORT
		$(test "$gnuArch" = 's390x-linux-musl' && echo '--without-pcre-jit') \
		\
		${PHP_EXTRA_CONFIGURE_ARGS:-} \
	; \
    make -j "$(nproc)"; \
	find -type f -name '*.a' -delete; \
	make install; \
	find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; \
	make clean; \
	\
# https://github.com/docker-library/php/issues/692 (copy default example "php.ini" files somewhere easily discoverable)
	cp -v php.ini-* "$PHP_INI_DIR/"; \
	\
	cd /; \
	docker-php-source delete; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-cache $runDeps; \
	\
	apk del --no-network .build-deps; \
	\
# update pecl channel definitions https://github.com/docker-library/php/issues/443
	pecl update-channels; \
	rm -rf /tmp/pear ~/.pearrc; \
# smoke test
	php --version





COPY content/index.html /var/www/html/index.html
COPY docker-php-ext-* /usr/local/bin/

USER joesmith

WORKDIR $APP_ROOT
EXPOSE 80
STOPSIGNAL SIGQUIT
EXPOSE 9000

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["sudo", "nginx"]
