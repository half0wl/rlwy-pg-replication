FROM postgres:16-bookworm

RUN apt-get update && \
    apt-get install -y \
    curl \
    sudo \
    vim \
    postgresql-16-repmgr \
    && rm -rf /var/lib/apt/lists/*

RUN echo \
    "postgres ALL=(root) NOPASSWD: /usr/bin/mkdir, /bin/chown, \
    /usr/bin/openssl, /usr/bin/repmgr, /usr/bin/psql" \
    > /etc/sudoers.d/postgres

COPY --chmod=755 _include.sh /usr/local/bin/_include.sh
COPY --chmod=755 _common.sh /usr/local/bin/_common.sh
COPY --chmod=755 configure-replica.sh /usr/local/bin/configure-replica.sh
COPY --chmod=755 ssl.sh /usr/local/bin/ssl.sh
COPY --chmod=755 run.sh /usr/local/bin/run.sh

ENTRYPOINT ["run.sh"]
CMD ["postgres", "-p", "5432", "-c", "listen_addresses=*"]
