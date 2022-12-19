#Install the required packages
apt update
apt install -y \
    postgresql \
    postgresql-contrib \
    phppgadmin
apt clean
systemctl enable postgresql
echo '<html><head><meta http-equiv="Refresh" content="0; url=/phppgadmin"></head><body></body></html>' > /var/www/html/index.html
