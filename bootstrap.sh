#!/bin/bash

# To run do: curl https://example.com/bootstrap.sh | bash && source ~/.profile
#
# Based on Amazon EC2 AMI ID ami-ccf405a5 Ubuntu Server 10.10
# This script will:
# * install/config apache2
# * install mod_wsgi
# * install/config nginx
# * install/config mysql
# * isntall pip
# * install virtualenv
# * install/config virtualenvwrapper
# * create webapps folder
# * install/config git
# * install git-flow
# * create the django.wsgi you will need in ~/django.wsgi
#
# Once this setup is completed you must do the following to complete deployment:
# * Clone your project into $apps_dir
#   - Static files must be in $apps_dir/$project_name/static
#   - If you are using the admin app create a symlink to its media files in $apps_dir/$project_name/static
# * Move the django.wsgi file to $apps_dir/$project_name/django.wsgi
# * sudo chown -R www-data:www-data $apps_dir
# * Restart apache

# Clean prompt
clear

# Define user settings
echo "Enter project name [project]:"
read project_name
if [[ $project_name = "" ]]; then
  project_name="project"
fi

echo "Enter apps directory [/var/webapps]:"
read apps_dir
if [[ $apps_dir = "" ]]; then
  apps_dir="/var/webapps"
fi

echo "Enter domains separated by space [example.com www.example.com]:"
read domains
if [[ $domains = "" ]]; then
  domains="example.com www.example.com"
fi

echo "Enter password for mysql's root user [password]:"
read dbpass
if [[ $dbpass = "" ]]; then
  dbpass="password"
fi

echo "Enter path for virtualenvs [/var/virtualenvs]"
read virtualenv_dir
if [[ $virtualenv_dir = "" ]]; then
  virtualenv_dir="/var/virtualenvs"
fi

echo "Git user name [Server]:"
read git_name
if [[ $git_name = "" ]]; then
  git_name="Server"
fi

echo "Git user email [root@localhost]:"
read git_email
if [[ $git_email = "" ]]; then
  git_email="root@localhost"
fi


# Do the dirty work
echo "This will take a few minutes..."
sudo apt-get update -qq
sudo apt-get upgrade -qq
echo "mysql-server mysql-server/root_password select $dbpass" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again select $dbpass" | sudo debconf-set-selections
sudo apt-get install -qq mysql-server
sudo apt-get install -qq mysql-client
sudo apt-get install -qq apache2 libapache2-mod-wsgi
sudo apt-get install -qq nginx
sudo apt-get install -qq python-setuptools python-dev build-essential python-pip
sudo apt-get install -qq nginx
sudo pip install django
sudo pip install fabric
sudo pip install virtualenv
sudo pip install virtualenvwrapper

# Apache setup: serv application with mod_wsgi
# /etc/apache2/sites-available/default
touch ~/default
echo "<VirtualHost *:8080>
	ServerAdmin webmaster@localhost
	WSGIScriptAlias / /var/webapps/$project_name/django.wsgi
	<Directory />
		Order allow,deny
		Allow from all
	</Directory>
	ErrorLog ${APACHE_LOG_DIR}/error.log
	LogLevel warn
	CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" > ~/default
sudo rm -rf /etc/apache2/sites-available/default
sudo mv ~/default /etc/apache2/sites-available/default
sudo chown root:root /etc/apache2/sites-available/default

# /etc/apache2/ports.conf
touch ~/ports.conf
echo "NameVirtualHost *:8080
Listen 8080
<IfModule mod_ssl.c>
    Listen 443
</IfModule>
<IfModule mod_gnutls.c>
    Listen 443
</IfModule>" > ~/ports.conf
sudo rm -rf /etc/apache2/ports.conf
sudo mv ~/ports.conf /etc/apache2/ports.conf
sudo chown root:root /etc/apache2/ports.conf

# restart apache
sudo /etc/init.d/apache2 restart

# Nginx setup: serv media files and proxy all other request
# /etc/nginx/nginx.conf
touch ~/nginx.conf
echo "user www-data;
worker_processes  2;
error_log  /var/log/nginx/error.log;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    access_log  /var/log/nginx/access.log;
    sendfile        on;
    tcp_nopush     on;
    keepalive_timeout  65;
    tcp_nodelay        on;
    gzip  on;
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}" > ~/nginx.conf
sudo rm -rf /etc/nginx/nginx.conf
sudo mv ~/nginx.conf /etc/nginx/nginx.conf
sudo chown root:root /etc/nginx/nginx.conf

# /etc/nginx/sites-enabled/default
touch ~/default
echo "server {
	listen   80; ## listen for ipv4
	listen   [::]:80 default ipv6only=on; ## listen for ipv6
	server_name $domains;
	access_log  /var/log/nginx/localhost.access.log;
	error_log /var/log/nginx/localhost.error.log;
	location / {
    proxy_pass http://127.0.0.1:8080;
    include /etc/nginx/proxy.conf;
  }
  location /static/ {
    root   /var/webapps/$project_name/;
  }
}" > ~/default
sudo rm -rf /etc/nginx/sites-available/default
sudo mv ~/default /etc/nginx/sites-available/default
sudo chown root:root /etc/nginx/sites-available/default

# /etc/nginx/proxy.conf
touch ~/proxy.conf
echo 'proxy_redirect              off;
proxy_set_header            Host $host;
proxy_set_header            X-Real-IP $remote_addr;
proxy_set_header            X-Forwarded-For $proxy_add_x_forwarded_for;
client_max_body_size        10m;
client_body_buffer_size     128k;
proxy_connect_timeout       90;
proxy_send_timeout          90;
proxy_read_timeout          90;
proxy_buffer_size           4k;
proxy_buffers               4 32k;
proxy_busy_buffers_size     64k;
proxy_temp_file_write_size  64k;
' > ~/proxy.conf
sudo rm -rf /etc/nginx/proxy.conf
sudo mv ~/proxy.conf /etc/nginx/proxy.conf
sudo chown root:root /etc/nginx/proxy.conf

# restart nginx
sudo /etc/init.d/nginx restart

# Make virtualenvwrapper work
sudo mkdir $virtualenv_dir
sudo chown -R ubuntu:ubuntu $virtualenv_dir
echo "export WORKON_HOME=/var/virtualenvs" >> ~/.profile
echo "source /usr/local/bin/virtualenvwrapper.sh" >> ~/.profile

# Create WebApps Folder
sudo mkdir $apps_dir
sudo chown -R www-data:www-data $apps_dir

# Git
sudo apt-get -qq install git
git config --global user.name $git_name
git config --global user.email $git_email

# Git-flow - TODO:Fix it!
# git clone --recursive git://github.com/nvie/gitflow.git
# sudo make -f ~/gitflow/Makefile install
# rm -Rf ./gitflow

# Create django.wsgi
echo "import os
import sys
path = '$apps_dir'
if path not in sys.path:
    sys.path.append(path)
os.environ['DJANGO_SETTINGS_MODULE'] = '$project_name.settings'
import django.core.handlers.wsgi
application = django.core.handlers.wsgi.WSGIHandler()" > ~/django.wsgi

echo "All done now!"