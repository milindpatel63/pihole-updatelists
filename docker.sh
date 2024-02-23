#!/bin/bash
# This is the startup file for Docker installation that runs before actual _postFTL service is started

if [ ! -d "/etc/s6-overlay/s6-rc.d/_postFTL" ]; then
	echo "Missing /etc/s6-overlay/s6-rc.d/_postFTL - not a Docker installation?"
	exit
fi

# Respect PH_VERBOSE environment variable
if [ "${PH_VERBOSE:-0}" -gt 0 ]; then
	set -x
	SCRIPT_ARGS="--verbose --debug"
fi

# Recreate the config file if it is missing
if [ ! -f "/etc/pihole-updatelists/pihole-updatelists.conf" ]; then
	cp /etc/pihole-updatelists.conf /etc/pihole-updatelists/pihole-updatelists.conf
	echo "Created /etc/pihole-updatelists/pihole-updatelists.conf"
fi

# Fix permissions (when config directory is mounted as a volume)
chown root:root /etc/pihole-updatelists/*
chmod 644 /etc/pihole-updatelists/*

# Disable default gravity update schedule
if [ "$(grep 'pihole updateGravity' < /etc/cron.d/pihole | cut -c1-1)" != "#" ]; then
	sed -e '/pihole updateGravity/ s/^#*/#/' -i /etc/cron.d/pihole
	echo "Disabled default gravity update schedule in /etc/cron.d/pihole"
fi

# Create new schedule with random time
echo "33 3 * * 6   root   /usr/bin/runitor -uuid=\"6c4e7360-c523-4e3a-859f-04db7c1b9d3d\" -api-url=\"https://hc-ping.com\" -api-retries=5 -api-timeout=\"10s\" -- /usr/local/sbin/pihole-updatelists --config=/etc/pihole-updatelists/pihole-updatelists.conf" > /etc/cron.d/pihole-updatelists
#sed "s/#30 /$((1 + RANDOM % 58)) /" -i /etc/cron.d/pihole-updatelists

if [ -n "$SKIPGRAVITYONBOOT" ]; then
	echo "Lists update skipped - SKIPGRAVITYONBOOT=true"
else
	if [ ! -f "/etc/pihole/gravity.db" ]; then
		echo "Gravity database not found - running 'pihole -g' command..."
		pihole -g
	else
		if [ -z "$PHUL_SKIPDNSCHECK" ]; then
			[ -n "$PHUL_DNSCHECK_DOMAIN" ] && _DNSCHECK_DOMAIN="$PHUL_DNSCHECK_DOMAIN" || _DNSCHECK_DOMAIN="pi-hole.net"
			[ -n "$PHUL_DNSCHECK_TIMELIMIT" ] && _DNSCHECK_TIMELIMIT="$PHUL_DNSCHECK_TIMELIMIT" || _DNSCHECK_TIMELIMIT=300

			_DNSCHECK_COUNTER=0
			while [ -z "$_DNSCHECK_IP" ] && [ "$_DNSCHECK_COUNTER" -lt "$_DNSCHECK_TIMELIMIT" ]; do
				_DNSCHECK_IP="$(nslookup "$_DNSCHECK_DOMAIN" | awk '/^Address: / { print $2 }')"

				if [ -z "$_DNSCHECK_IP" ]; then
					[ "$_DNSCHECK_COUNTER" = 0 ] && echo "Waiting for DNS resolution to be available..."

					sleep 1
				fi

				((_DNSCHECK_COUNTER++))
			done

			[ -z "$_DNSCHECK_IP" ] && echo "Timed out while waiting for DNS resolution to be available"
		fi
	fi

	if [ -z "$PHUL_LOG_FILE" ]; then
		export PHUL_LOG_FILE="-/var/log/pihole-updatelists-boot.log"
	fi

	# shellcheck disable=SC2086
	/usr/bin/php /usr/local/sbin/pihole-updatelists --config=/etc/pihole-updatelists/pihole-updatelists.conf --env --no-gravity --no-reload $SCRIPT_ARGS
fi
