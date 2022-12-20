apt update
apt install -y \
    ansible \
    python3-psycopg2 \
    postgresql \
    postgresql-contrib \
    phppgadmin
apt clean

ansible-playbook /tmp/playbook.yaml
