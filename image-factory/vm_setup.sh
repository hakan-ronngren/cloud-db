#Install the required packages
apt update
apt install -y postgresql postgresql-contrib
apt clean
systemctl enable postgresql
