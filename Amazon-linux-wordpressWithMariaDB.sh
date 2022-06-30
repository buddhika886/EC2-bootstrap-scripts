#!/bin/bash
# AUTOMATIC WORDPRESS INSTALLER IN  AWS LINUX 2 AMI WITH MARIA DB
# mysql  Ver 15.1 Distrib 5.5.68-MariaDB, for Linux (x86_64) using readline 5.1


#Change these values and keep in safe place
db_root_password=PassWord4root
db_username=root
db_user_password=PassWord4root
db_name=wordpress_db

# Update Server
yum update -y
#install apache server
yum install -y httpd
 
#since amazon ami 2018 is no longer supported ,to install latest php and mysql we have to do some tricks.
#first enable php7.xx from  amazon-linux-extra and install it

amazon-linux-extras enable php7.4
yum clean metadata
yum install -y php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap,devel}
#install imagick extension
yum -y install gcc ImageMagick ImageMagick-devel ImageMagick-perl
pecl install imagick
chmod 755 /usr/lib64/php/modules/imagick.so
cat <<EOF >>/etc/php.d/20-imagick.ini

extension=imagick

EOF

systemctl restart php-fpm.service

#and download mariaDB package to yum  and install mysql server from yum
sudo yum install -y mariadb-server
sudo systemctl enable mariadb
sudo systemctl start mariadb



systemctl start  httpd

# Change OWNER and permission of directory /var/www
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;

# Download wordpress package and extract
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -r wordpress/* /var/www/html/


# Create database user and grant privileges
mysql -u root -e "FLUSH PRIVILEGES;"
mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$db_root_password');"
mysql -u root -p"$db_root_password" -e "UPDATE mysql.user SET authentication_string = PASSWORD('$db_root_password') WHERE User = 'root' AND Host = 'localhost';"


# Create database
mysql -u root -p"$db_root_password" -e "CREATE DATABASE wordpress_db;"

# Create wordpress configuration file and update database value
cd /var/www/html
cp wp-config-sample.php wp-config.php

sed -i "s/database_name_here/$db_name/g" wp-config.php
sed -i "s/username_here/$db_username/g" wp-config.php
sed -i "s/password_here/$db_user_password/g" wp-config.php
cat <<EOF >>/var/www/html/wp-config.php

define( 'FS_METHOD', 'direct' );
define('WP_MEMORY_LIMIT', '256M');
EOF

# Change permission of /var/www/html/
chown -R ec2-user:apache /var/www/html
chmod -R 774 /var/www/html

#  enable .htaccess files in Apache config using sed command
sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' /etc/httpd/conf/httpd.conf

#Make apache and mysql to autostart and restart apache
systemctl enable  httpd.service
systemctl restart httpd.service
systemctl enable mysqld.service
