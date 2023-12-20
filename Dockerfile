#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM alpine:3.19

RUN set -eux; \
    apk add --no-cache \
    bzip2 \
    ca-certificates \
    gmp-dev \
    libffi-dev \
    procps \
    yaml-dev \
    zlib-dev \
    ;

# skip installing gem documentation
RUN set -eux; \
    mkdir -p /usr/local/etc; \
    { \
    echo 'install: --no-document'; \
    echo 'update: --no-document'; \
    } >> /usr/local/etc/gemrc

ENV LANG C.UTF-8
ENV RUBY_MAJOR 3.2
ENV RUBY_VERSION 3.2.2
ENV RUBY_DOWNLOAD_SHA256 4b352d0f7ec384e332e3e44cdbfdcd5ff2d594af3c8296b5636c710975149e23

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
RUN set -eux; \
    \
    apk add --no-cache --virtual .ruby-builddeps \
    autoconf \
    bison \
    bzip2 \
    bzip2-dev \
    ca-certificates \
    coreutils \
    dpkg-dev dpkg \
    g++ \
    gcc \
    gdbm-dev \
    glib-dev \
    libc-dev \
    libffi-dev \
    libxml2-dev \
    libxslt-dev \
    linux-headers \
    make \
    ncurses-dev \
    openssl \
    openssl-dev \
    patch \
    procps \
    readline-dev \
    ruby \
    tar \
    xz \
    yaml-dev \
    zlib-dev \
    ; \
    \
    rustArch=; \
    apkArch="$(apk --print-arch)"; \
    case "$apkArch" in \
    'x86_64') rustArch='x86_64-unknown-linux-musl'; rustupUrl='https://static.rust-lang.org/rustup/archive/1.26.0/x86_64-unknown-linux-musl/rustup-init'; rustupSha256='7aa9e2a380a9958fc1fc426a3323209b2c86181c6816640979580f62ff7d48d4' ;; \
    'aarch64') rustArch='aarch64-unknown-linux-musl'; rustupUrl='https://static.rust-lang.org/rustup/archive/1.26.0/aarch64-unknown-linux-musl/rustup-init'; rustupSha256='b1962dfc18e1fd47d01341e6897cace67cddfabf547ef394e8883939bd6e002e' ;; \
    esac; \
    \
    if [ -n "$rustArch" ]; then \
    mkdir -p /tmp/rust; \
    \
    wget -O /tmp/rust/rustup-init "$rustupUrl"; \
    echo "$rustupSha256 */tmp/rust/rustup-init" | sha256sum --check --strict; \
    chmod +x /tmp/rust/rustup-init; \
    \
    export RUSTUP_HOME='/tmp/rust/rustup' CARGO_HOME='/tmp/rust/cargo'; \
    export PATH="$CARGO_HOME/bin:$PATH"; \
    /tmp/rust/rustup-init -y --no-modify-path --profile minimal --default-toolchain '1.74.1' --default-host "$rustArch"; \
    \
    rustc --version; \
    cargo --version; \
    fi; \
    \
    wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz"; \
    echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum --check --strict; \
    \
    mkdir -p /usr/src/ruby; \
    tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1; \
    rm ruby.tar.xz; \
    \
    cd /usr/src/ruby; \
    \
    # https://github.com/docker-library/ruby/issues/196
    # https://bugs.ruby-lang.org/issues/14387#note-13 (patch source)
    # https://bugs.ruby-lang.org/issues/14387#note-16 ("Therefore ncopa's patch looks good for me in general." -- only breaks glibc which doesn't matter here)
    wget -O 'thread-stack-fix.patch' 'https://bugs.ruby-lang.org/attachments/download/7081/0001-thread_pthread.c-make-get_main_stack-portable-on-lin.patch'; \
    echo '3ab628a51d92fdf0d2b5835e93564857aea73e0c1de00313864a94a6255cb645 *thread-stack-fix.patch' | sha256sum --check --strict; \
    patch -p1 -i thread-stack-fix.patch; \
    rm thread-stack-fix.patch; \
    \
    # the configure script does not detect isnan/isinf as macros
    export ac_cv_func_isnan=yes ac_cv_func_isinf=yes; \
    \
    # hack in "ENABLE_PATH_CHECK" disabling to suppress:
    #   warning: Insecure world writable dir
    { \
    echo '#define ENABLE_PATH_CHECK 0'; \
    echo; \
    cat file.c; \
    } > file.c.new; \
    mv file.c.new file.c; \
    \
    autoconf; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    ./configure \
    --build="$gnuArch" \
    --disable-install-doc \
    --enable-shared \
    ${rustArch:+--enable-yjit} \
    ; \
    make -j "$(nproc)"; \
    make install; \
    \
    rm -rf /tmp/rust; \
    runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
    | tr ',' '\n' \
    | sort -u \
    | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-network --virtual .ruby-rundeps $runDeps; \
    apk del --no-network .ruby-builddeps; \
    \
    cd /; \
    rm -r /usr/src/ruby; \
    # verify we have no "ruby" packages installed
    if \
    apk --no-network list --installed \
    | grep -v '^[.]ruby-rundeps' \
    | grep -i ruby \
    ; then \
    exit 1; \
    fi; \
    [ "$(command -v ruby)" = '/usr/local/bin/ruby' ]; \
    # rough smoke test
    ruby --version; \
    gem --version; \
    bundle --version

# don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_SILENCE_ROOT_WARNING=1 \
    BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $GEM_HOME/bin:$PATH
# adjust permissions of a few directories for running "gem install" as an arbitrary user
RUN mkdir -p "$GEM_HOME" && chmod 1777 "$GEM_HOME"

#new Added
# Install dependencies
RUN apk update && apk add --no-cache build-base postgresql-dev nodejs

ENV RAILS_ROOT /var/www/projectM
RUN mkdir -p $RAILS_ROOT

# Install tzdata because we need the zic binary
RUN apk add --no-cache tzdata

# # Fix incompatibility with slim tzdata from 2020b onwards
# RUN wget https://data.iana.org/time-zones/tzdb/tzdata.zi -O /usr/share/zoneinfo/tzdata.zi && \
#     /usr/sbin/zic -b fat /usr/share/zoneinfo/tzdata.zi

# Set working directory, where the commands will be ran:
WORKDIR $RAILS_ROOT
# ENV POSTGRES_PASSWORD='example'
ENV POSTGRES_USER='postgres'
ENV VICHAR_DATABASE_PASSWORD='example'

# Setting env up
# ENV RAILS_ENV='production'
# ENV RACK_ENV='production'


RUN apk add --no-cache zlib-dev  patch
RUN apk add  \
    libxml2-dev \
    libxslt-dev \
    # liblzma-dev \
    openssl-dev \
    libffi-dev \
    zlib-dev 

# RUN bundle lock --add-platform x86_64-linux
# RUN gem install nokogiri --platform=ruby
# Install dependencies
RUN apk add --no-cache build-base libxml2-dev libxslt-dev



# --jobs 20 --retry 5 --without development test
# RUN rm -f /myapp/tmp/pids/server.pid
# RUN rails db:migrate


# Adding project files
# COPY ./vicharBk .
# RUN mkdir tmp/pids -p
# RUN chmod +x /var/www/vichar/lib/docker-entrypoint.sh
RUN apk add --no-cache libcurl
RUN gem install typhoeus 


# Adding gems
COPY ./projectM/Gemfile Gemfile
# COPY ./ProjectM/Gemfile.lock Gemfile.lock
RUN bundle lock --add-platform x86_64-linux
RUN bundle install 

RUN apk add --no-cache libxml2 libxslt && \
    apk add --no-cache --virtual .gem-installdeps build-base libxml2-dev libxslt-dev && \
    gem install nokogiri --platform=ruby -- --use-system-libraries && \
    rm -rf $GEM_HOME/cache && \
    apk del .gem-installdeps

# RUN gem install sqlite3 -- --with-sqlite3-include=dir --with-sqlite3-lib=dir    


# Install nokogiri gem
# RUN apk add --no-cache build-base libxml2-dev libxslt-dev
# RUN gem install nokogiri --platform=ruby -- --use-system-libraries


EXPOSE 3000
# RUN rails db:create
# CMD ["bundle", "exec", "puma","-e","production", "-C", "config/puma.rb"]
# CMD ["bundle", "exec", "puma","-e","production", "-C", "config/puma.rb"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]


# docker exec -it new_project-vichar_app-1 bash
# docker compose up --build
# New_project % docker run -p 3000:3000 --network pgn ani/vicharapp rake db:migrate
# docker run -p 3000:3000 --network pgn ani/vicharapp rake


# docker system prune -a      
# Clear Docker unused/all images



# pg_restore --verbose --clean --no-acl --no-owner -h localhost -U myuser -d mydb latest.dump


# CMD [ "irb" ]

# docker build -t prom-rails .
# docker run -p 3000:3000 -v $(pwd)/projectM:/var/www/projectM prom-rails