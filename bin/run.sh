#!/bin/bash

# Bootstrap application
echo "Preparing environment... (This will take some time...)"

if [ ! -f /etc/icinga2/.installed ]; then
  cp -r /opt/icinga2/default_config/icinga2/* /etc/icinga2/
  icinga2 feature enable checker
  icinga2 feature enable command

  i=0
  echo -n "Waiting for database connection"
  until nc -z -v -w30 ${DB_HOST} 3306
  do
    if [ $i -gt 60 ]; then
      echo "Couldn't connect to database!" >&2
      exit 1
    fi
    echo -n "."
    sleep 1
    let i++
  done
  echo " done"
  echo -n "Waiting for mysql to respond"
  until mysqladmin ping -h"${DB_HOST}" --silent
  do
    if [ $i -gt 60 ]; then
      echo "Couldn't connect to database!" >&2
      exit 1
    fi
    echo -n "."
    sleep 1
    let i++
  done
  echo " done"

  echo "Creating databases and users..."
  mysql -u "root" -p"${DB_ROOT_PW}" -h "${DB_HOST}" -e "CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_ROOT_PW}';"
  mysql -u "root" -p"${DB_ROOT_PW}" -h "${DB_HOST}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}; GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO ${DB_USER}@'%';"
  mysql -u "root" -p"${DB_ROOT_PW}" -h "${DB_HOST}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME_WEB}; GRANT ALL PRIVILEGES ON ${DB_NAME_WEB}.* TO ${DB_USER}@'%';"

  echo "Creating schema...."
  mysql -u "${DB_USER}" -p"${DB_ROOT_PW}" -h "${DB_HOST}" -D "${DB_NAME}" < /usr/share/icinga2-ido-mysql/schema/mysql.sql
  mysql -u "${DB_USER}" -p"${DB_ROOT_PW}" -h "${DB_HOST}" -D "${DB_NAME_WEB}" < /usr/share/webapps/icingaweb2/etc/schema/mysql.schema.sql

  echo "Creating default icingaweb2 user (admin/admin)..."
  mysql -u "${DB_USER}" -p"${DB_ROOT_PW}" -h "${DB_HOST}" -D "${DB_NAME_WEB}" -e "INSERT INTO icingaweb_user (name, active, password_hash) VALUES ('admin', 1, '\$1\$GSwrn03C\$ssgt3XgIogP3BrWF2kw0N.');"
  mysql -u "${DB_USER}" -p"${DB_ROOT_PW}" -h "${DB_HOST}" -D "${DB_NAME_WEB}" -e "INSERT INTO icingaweb_group (name) VALUES ('Administrators');"
  mysql -u "${DB_USER}" -p"${DB_ROOT_PW}" -h "${DB_HOST}" -D "${DB_NAME_WEB}" -e "INSERT INTO icingaweb_group_membership (group_id, username) VALUES (1, 'admin');"

  echo "Creating mysql configuration for incinga2...";
  sed -i "s/##DB_HOST##/${DB_HOST}/g" /etc/icinga2/features-available/ido-mysql.conf
  sed -i "s/##DB_NAME##/${DB_NAME}/g" /etc/icinga2/features-available/ido-mysql.conf
  sed -i "s/##DB_USER##/${DB_USER}/g" /etc/icinga2/features-available/ido-mysql.conf
  sed -i "s/##DB_PW##/${DB_ROOT_PW}/g" /etc/icinga2/features-available/ido-mysql.conf
  icinga2 feature enable ido-mysql

  echo "Creating configuration for icingaweb2...";
  cp -r /opt/icinga2/default_config/icingaweb2/* /etc/icingaweb2
  sed -i "s/##DB_HOST##/${DB_HOST}/g" /etc/icingaweb2/resources.ini
  sed -i "s/##DB_NAME##/${DB_NAME}/g" /etc/icingaweb2/resources.ini
  sed -i "s/##DB_NAME_WEB##/${DB_NAME_WEB}/g" /etc/icingaweb2/resources.ini
  sed -i "s/##DB_USER##/${DB_USER}/g" /etc/icingaweb2/resources.ini
  sed -i "s/##DB_PW##/${DB_ROOT_PW}/g" /etc/icingaweb2/resources.ini

  mkdir /etc/icingaweb2/enabledModules
  rm -f /etc/icingaweb2/setup.token
  chown -R nginx:icingaweb2 /etc/icingaweb2

  echo "Enabling monitoring module for icingaweb2...";
  ln -s /usr/share/webapps/icingaweb2/modules/monitoring /etc/icingaweb2/enabledModules/

  touch /etc/icinga2/.installed
  echo "!!!NEVER REMOVE THIS FILE!!!" > /etc/icinga2/.installed
fi

echo <<< EOL
root=postmaster
mailhub=${SMTP_SERVER}
hostname=icinga
EOL >> /etc/ssmtp/ssmtp.conf;

# run application
echo "Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
