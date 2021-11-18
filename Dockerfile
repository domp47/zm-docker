FROM ubuntu:20.04

ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


# Compile Zoneminder

RUN apt-get update \
 && apt-get install -y curl git make cmake g++ default-libmysqlclient-dev libavcodec-dev libavformat-dev libavutil-dev libswresample-dev libswscale-dev libjwt-dev \
    libcurl4-gnutls-dev libvlc-dev libvncserver-dev libdate-manip-perl libdbd-mysql-perl libsys-mmap-perl libwww-perl libpolkit-gobject-1-dev libssl-dev libdigest-bcrypt-perl \
    apache2 mysql-server php libapache2-mod-php php-mysql libcrypt-eksblowfish-perl libdata-entropy-perl libsys-meminfo-perl libnumber-bytes-human-perl

RUN ver=$(curl -s "https://api.github.com/repos/zoneminder/zoneminder/releases/latest" | python3 -c "import sys, json; print(json.load(sys.stdin)['tag_name'])") \
 && git clone "https://github.com/ZoneMinder/ZoneMinder.git" "/tmp/zoneminder" \
 && cd /tmp/zoneminder \
 && git checkout $ver \
 && git submodule init \
 && git submodule update --init --recursive \
 && rm -rf .git \
 && rm .gitignore

RUN mkdir /tmp/zoneminder/build \
 && cd /tmp/zoneminder/build \
 && cmake --version && cmake .. -DBUILD_MAN=0 -DCMAKE_BUILD_TYPE=Release -DZM_CONFIG_DIR="/etc/zm" -DZM_CONFIG_SUBDIR="/etc/zm/conf.d" -DZM_RUNDIR="/run/zm" -DZM_SOCKDIR="/run/zm" -DZM_TMPDIR="/var/tmp/zm" -DZM_CGIDIR="/usr/lib/zoneminder/cgi-bin" -DZM_CACHEDIR="/var/cache/zoneminder/cache" -DZM_DIR_EVENTS="/var/lib/zoneminder/events" -DZM_PATH_SHUTDOWN="/sbin/shutdown" -DZM_PATH_ZMS="/zm/cgi-bin/nph-zms"

RUN cd /tmp/zoneminder/build \
 && cmake --build ./ -- -j8 \
 && make install

RUN rm -r /tmp/zoneminder

# Get the entrypoint script
COPY entrypoint.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/entrypoint.sh

# Set our volumes before we do anything else
VOLUME /var/lib/zoneminder/events /var/lib/mysql /var/log/zm

# Expose http port
EXPOSE 80

# Set up ownership on config & ui
RUN chmod 740 /etc/zm/zm.conf \
 && chown root:www-data /etc/zm/zm.conf \
 && chown -R www-data:www-data /usr/local/share/zoneminder 

# Add Apache config and create cache folder
COPY zoneminder.conf /etc/apache2/conf-available
RUN mkdir -p /var/cache/zoneminder/cache \
 && chown -R www-data:www-data /var/lib/zoneminder/events \
 && chown -R www-data:www-data /var/cache/zoneminder

RUN a2enmod cgi \
 && a2enmod rewrite \
 && a2enconf zoneminder \
 && a2enmod expires \
 && a2enmod headers

# This is run each time the container is started
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]