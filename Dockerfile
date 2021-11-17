FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York

# Compile Zoneminder

RUN apt-get update \
 && apt-get install -y curl git make cmake g++ default-libmysqlclient-dev libavcodec-dev libavformat-dev libavutil-dev libswresample-dev libswscale-dev libjwt-dev \
    libcurl4-gnutls-dev libvlc-dev libvncserver-dev libdate-manip-perl libdbd-mysql-perl libsys-mmap-perl libwww-perl libpolkit-gobject-1-dev libssl-dev libdigest-bcrypt-perl \
    apache2 mysql-server php libapache2-mod-php php-mysql libcrypt-eksblowfish-perl libdata-entropy-perl libsys-meminfo-perl

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
 && cmake --version && cmake .. -DBUILD_MAN=0 -DCMAKE_BUILD_TYPE=Release

RUN cd /tmp/zoneminder/build \
 && cmake --build ./ -- -j8 \
 && make install

# Get the entrypoint script
ADD https://raw.githubusercontent.com/ZoneMinder/zmdockerfiles/master/utils/entrypoint.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/entrypoint.sh

# Set our volumes before we do anything else
VOLUME /var/lib/zoneminder/events /var/lib/mysql /var/log/zm

# Expose http port
EXPOSE 80

# Set up ownership on config & ui
RUN chmod 740 /etc/zm.conf \
 && chown root:www-data /etc/zm.conf \
 && chown -R www-data:www-data /usr/local/share/zoneminder

# Add Apache config and create cache folder
COPY zoneminder.conf /etc/apache2/conf-available
RUN mkdir /var/cache/zoneminder

RUN a2enmod cgi \
 && a2enmod rewrite \
 && a2enconf zoneminder \
 && a2enmod expires \
 && a2enmod headers

# This is run each time the container is started
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]