FROM pihole/pihole:latest

COPY install.sh docker.sh pihole-updatelists.* /tmp/pihole-updatelists/

COPY runitor /usr/bin/runitor

RUN apt-get update && \
    apt-get install -Vy wget php-cli php-sqlite3 php-intl php-curl && \
    apt-get clean && \
    rm -fr /var/cache/apt/* /var/lib/apt/lists/*.lz4

RUN chmod +x /tmp/pihole-updatelists/install.sh && \
    chmod +x /usr/bin/runitor && \
    bash /tmp/pihole-updatelists/install.sh docker && \
    rm -fr /tmp/pihole-updatelists
