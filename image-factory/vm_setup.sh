# Set up the PostgreSQL data partition on a separate disk
# mkdir -p /var/lib/postgresql
# sudo mkfs -t ext4 /dev/sdb
# echo '/dev/sdb /var/lib/postgresql ext4 defaults 0 2' >> /etc/fstab
# mount /var/lib/postgresql

apt update
apt install -y postgresql postgresql-contrib
# chown -R postgres:postgres /var/lib/postgresql
# chmod 0770 /var/lib/postgresql
systemctl enable postgresql
systemctl start postgresql

# pg_ctlcluster 13 main start
