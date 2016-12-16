#!/bin/bash

# Bootstrap application
echo "Preparing environment... (This will take some time...)"

if [ ! -f /etc/icinga2/.installed ]; then
  cp -r /opt/icinga2/default_config/icinga2/* /etc/icinga2/
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

  echo "Creating database..."
  mysql -u "${DB_USER}" -p"${DB_PW}" -h "${DB_HOST}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
  mysql -u "${DB_USER}" -p"${DB_PW}" -h "${DB_HOST}" -D "${DB_NAME}" < /usr/share/icinga2-ido-mysql/schema/mysql.sql

  sed -i "s/##DB_HOST##/${DB_HOST}/g" /etc/icinga2/features-available/ido-mysql.conf
  sed -i "s/##DB_NAME##/${DB_NAME}/g" /etc/icinga2/features-available/ido-mysql.conf
  sed -i "s/##DB_USER##/${DB_USER}/g" /etc/icinga2/features-available/ido-mysql.conf
  sed -i "s/##DB_PW##/${DB_PW}/g" /etc/icinga2/features-available/ido-mysql.conf
  icinga2 feature enable ido-mysql

  touch /etc/icinga2/.installed
  echo "!!!NEVER REMOVE THIS FILE!!!" > /etc/icinga2/.installed
fi

# run application
echo "Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
