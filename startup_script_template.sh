# Set up the PostgreSQL data partition on the separate data disk
cd /
device=/dev/disk/by-id/google-db-data
mount_point=/var/lib/postgresql
echo "startup script running on `date`" >> /startup.log
echo "device=$${device}, mount_point=$${mount_point}" >> /startup.log
if ! grep -q "^$${device}" /etc/fstab ; then
    fsck $${device} ; if [ "$$?" -eq 8 ] ; then
        echo "formatting device" >> /startup.log
        mkfs -t ext4 $${device}
        formatted_at=`date`
    fi

    echo "stopping postgresql" >> /startup.log
    systemctl stop postgresql
    sleep 15
    tar cf /tmp/postgresql.tar $${mount_point}
    echo "writing to /etc/fstab and mounting data disk" >> /startup.log
    echo "$${device} $${mount_point} ext4 defaults 0 2" >> /etc/fstab
    mount $${mount_point}
    rm -f $${mount_point}/*/main/postmaster.pid
    if [ -n "$${formatted_at}" ] ; then
        echo "$${formatted_at}" > $${mount_point}/formatted_at
        echo "unpacking fresh database into $${mount_point}" >> /startup.log
        tar xf /tmp/postgresql.tar
    fi
    rm -f /tmp/postgresql.tar
    chown -R postgres:postgres $${mount_point}
    echo "starting postgresql" >> /startup.log
    systemctl start postgresql
fi

# Find the pg_hba.conf file in the highest-version postgresql config directory
hba_conf_path=`find /etc/postgresql -name pg_hba.conf | sort | tail -1`

%{ for schema in schemas ~}
echo "ensuring the presence of database ${schema}" >> /startup.log

ansible localhost --become --become-user postgres -c local \
    -m community.postgresql.postgresql_db \
    -a "name=${schema}"

ansible localhost --become --become-user postgres -c local \
    -m community.postgresql.postgresql_user \
    -a "db=${schema} name=${schema} password='${schema}'"

ansible localhost --become --become-user postgres -c local \
    -m community.postgresql.postgresql_pg_hba \
    -a "dest=$${hba_conf_path} contype=host databases=${schema} users=${schema} source=all method=password"
%{ endfor ~}

echo "ensuring the presence of the pgadmin user" >> /startup.log

ansible localhost --become --become-user postgres -c local \
    -m community.postgresql.postgresql_user \
    -a "name=pgadmin password='changeme' role_attr_flags=SUPERUSER"

ansible localhost --become --become-user postgres -c local \
    -m community.postgresql.postgresql_pg_hba \
    -a "dest=$${hba_conf_path} contype=host databases=all users=pgadmin source=127.0.0.1/32 method=md5"

echo "restarting postgresql" >> /startup.log
systemctl restart postgresql
