FROM alpine:3.5
MAINTAINER Simon Erhardt <hello@rootlogin.ch>

ENV DB_HOST="db" \
  DB_USER="icinga" \
  DB_NAME="icinga" \
  DB_NAME_WEB="icingaweb2" \
  DB_ROOT_PW="icinga" \
  SMTP_SERVER="localhost"

RUN apk add --update \
  bash \
  bc \
  ca-certificates \
  curl \
  icinga2 \
  icinga2-bash-completion \
  icingaweb2 \
  icingaweb2-bash-completion \
  mariadb-client \
  mailx \
  nginx \
  perl \
  php5-fpm \
  py2-pip \
  ssmtp \
  sudo \
  supervisor \
  tini \
  wget \
  && rm -rf /var/cache/apk/*

# Install monitoring plugins from source
RUN apk add --update \
  alpine-sdk \
  linux-headers \
  openssl-dev \
  perl-dev \
  && cd /tmp \
  && wget https://www.monitoring-plugins.org/download/monitoring-plugins-2.2.tar.gz \
  && tar xvzf monitoring-plugins-2.2.tar.gz \
  && cd monitoring-plugins-2.2 \
  && ./configure --prefix=/usr/local/monitoring \
  && make \
  && make install \
  && rm -rf /tmp/monitoring-plugins-2.2 \
  && apk del \
  alpine-sdk \
  linux-headers \
  openssl-dev \
  perl-dev \
  && rm -rf /var/cache/apk/*

# Install graphite
RUN apk add --update \
  alpine-sdk \
  fontconfig \
  git \
  libffi \
  libffi-dev \
  python-dev \
  uwsgi \
  && pip install cairocffi \
  && pip install django-tagging==0.4.3 \
  && pip install pytz \
  && pip install Django==1.9 \
  && mkdir -p /opt/graphite \
  # Install graphite web frontend
  && cd /opt/graphite \
  && git clone https://github.com/graphite-project/graphite-web.git \
  && cd /opt/graphite/graphite-web \
  && python setup.py install \
  # Install carbon
  && cd /opt/graphite \
  && git clone https://github.com/graphite-project/carbon.git \
  && cd /opt/graphite/carbon \
  && python setup.py install \
  # Install whisper
  && cd /opt/graphite \
  && git clone https://github.com/graphite-project/whisper.git \
  && cd /opt/graphite/whisper \
  && python setup.py install \
  # Install ceres
  && cd /opt/graphite \
  && git clone https://github.com/graphite-project/ceres.git \
  && cd /opt/graphite/ceres \
  && python setup.py install \
  && apk del \
  alpine-sdk \
  git \
  libffi-dev \
  && rm -rf /var/cache/apk/*

RUN pip install supervisor-stdout

RUN mkdir -p /run/icinga2/cmd && chown -R icinga:icinga /run/icinga2
RUN mkdir -p /opt/icinga2 \
  && mkdir /opt/icinga2/default_config \
  && cp -r /etc/icinga2 /opt/icinga2/default_config/

COPY etc/php /etc/php5
COPY etc/nginx /etc/nginx
COPY etc/icingaweb2 /opt/icinga2/default_config/icingaweb2
COPY etc/icinga2/constants.conf /opt/icinga2/default_config/icinga2/constants.conf
COPY etc/icinga2/ido-mysql.conf /opt/icinga2/default_config/icinga2/features-available/ido-mysql.conf
COPY etc/supervisord.conf /etc/supervisord.conf
COPY bin/run.sh /opt/icinga2/run.sh

RUN adduser nginx icingaweb2 \
  && adduser nginx icingacmd \
  && chmod +x /opt/icinga2/run.sh

# Enable suid for ping
RUN chmod +s /bin/ping

VOLUME ["/etc/icinga2", "/etc/icingaweb2", "/var/lib/icinga2"]

EXPOSE 80

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/opt/icinga2/run.sh"]
