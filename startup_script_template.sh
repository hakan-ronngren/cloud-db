cat > /root/playbook.yaml <<EOT
- hosts: localhost
  connection: local
  vars:
    fstype: ext4
    data_disk_device: /dev/disk/by-id/google-db-data
    pg_var_directory: /var/lib/postgresql
    initial_pg_var_tarball: /tmp/pgdata.tar.bz2
    sa_json_file: /root/service-account.json
    pg_backup_script: /root/psql-backup
  tasks:
    - name: Create the ll shell alias that I keep using
      ansible.builtin.lineinfile:
        path: /etc/bash.bashrc
        line: "alias ll='ls -l'"
        state: present

    - name: Determine the installed PostgreSQL version
      ansible.builtin.shell:
        chdir: /etc/postgresql
        cmd: "ls -1 | grep -E '^[0-9]+$'"
      register: pg_version_result
      changed_when: false

    - name: Register version as a fact
      ansible.builtin.set_fact:
        pg_version: "{{ pg_version_result.stdout }}"

    - name: Stop PostgreSQL
      ansible.builtin.systemd:
        name: postgresql
        state: stopped

    - name: List mounted directories
      ansible.builtin.command:
        cmd: df
      register: df_result
      changed_when: false

    - name: Unmount the data disk
      when: pg_var_directory in df_result.stdout
      ansible.builtin.command:
        cmd: "umount {{ pg_var_directory }}"
      register: unmount_result
      until: unmount_result is not failed
      retries: 30
      delay: 1

    - name: Have an {{ fstype }} filesystem expanded to the full size of the data disk
      community.general.filesystem:
        dev: "{{ data_disk_device }}"
        fstype: "{{ fstype }}"
        resizefs: yes

    - name: Configure the data disk mount point in fstab
      ansible.posix.mount:
        src: "{{ data_disk_device }}"
        path: "{{ pg_var_directory }}"
        fstype: "{{ fstype }}"
        state: present
        boot: true
        passno: "2"

    - name: Prepare a tarball of the unused pg data directory
      ansible.builtin.command:
        cmd: "tar cfj {{ initial_pg_var_tarball }} -C {{ pg_var_directory }} {{ pg_version }}"
      args:
        warn: false

    - name: Mount the data disk
      ansible.builtin.command:
        cmd: "mount {{ pg_var_directory }}"

    - name: Ensure proper ownership of the data directory
      file:
        path: "{{ pg_var_directory }}"
        owner: postgres
        group: postgres

    - name: See if there is a data directory for the current version in the mounted data directory
      ansible.builtin.stat:
        path: "{{ pg_var_directory }}/{{ pg_version }}"
      register: pg_data_result

    - name: Copy the initial pg data to the data disk
      when: not pg_data_result.stat.exists
      ansible.builtin.command:
        cmd: "tar xfj {{ initial_pg_var_tarball }} -C {{ pg_var_directory }}"
      args:
        warn: false

    - name: Delete the pg data tarball
      file:
        path: "{{ initial_pg_var_tarball }}"
        state: absent

    - name: Start PostgreSQL
      ansible.builtin.systemd:
        name: postgresql
        state: started

%{ for database in databases ~}

    - name: Ensure the presence of database ${database["name"]}
      become: yes
      become_user: postgres
      community.postgresql.postgresql_db:
        name: "${database["name"]}"

    - name: Ensure the presence of database user (role) ${database["user"]}
      become: yes
      become_user: postgres
      community.postgresql.postgresql_user:
        db: "${database["name"]}"
        name: "${database["user"]}"
        password: "${database["md5_password"]}"

    - name: Ensure a pg_hba rule for ${database["user"]} to log on
      become: yes
      become_user: postgres
      community.postgresql.postgresql_pg_hba:
        dest: /etc/postgresql/{{ pg_version }}/main/pg_hba.conf
        contype: host
        databases: "${database["name"]}"
        users: "${database["user"]}"
        source: all
        method: password
      notify: restart_service

%{ endfor ~}

    - name: Ensure the presence of the pgadmin user (web UI)
      become: yes
      become_user: postgres
      community.postgresql.postgresql_user:
        name: pgadmin
        password: changeme
        role_attr_flags: SUPERUSER

    - name: Ensure a pg_hba rule for the pgadmin user to log on
      become: yes
      become_user: postgres
      community.postgresql.postgresql_pg_hba:
        dest: /etc/postgresql/{{ pg_version }}/main/pg_hba.conf
        contype: host
        databases: all
        users: pgadmin
        source: 127.0.0.1/32
        method: md5
      notify: restart_service

    - name: Create backup script
      ansible.builtin.copy:
        content: |
          #!/bin/bash

          cd /

          dump_file=\`date +%Y%m%d-%H%M\`.sql
          local_path=/tmp/\$dump_file
          gs_url=gs://${bucket_name}/\$dump_file

          sudo -u postgres pg_dumpall > \$local_path
          gsutil -o 'Credentials:gs_service_key_file=/root/service-account.json' cp \$local_path \$gs_url
          rm \$local_path
        dest: "{{ pg_backup_script }}"
        mode: "0700"
        owner: root
        group: root

    - name: Set up cron job for backup
      ansible.builtin.copy:
        content: "0 12 * * * root {{ pg_backup_script }}\n"
        dest: /etc/cron.d/psqlbackup

    - name: Save service account json key
      ansible.builtin.copy:
        content: "{{ '${private_key}' | b64decode }}"
        dest: "{{ sa_json_file }}"
        mode: "0400"
        owner: root
        group: root

    - name: Write some instructions in motd
      ansible.builtin.copy:
        content: |+
          To connect as user "foo" to the "foo" database:

            $ psql -U foo -h localhost

        dest: /etc/motd

  handlers:
    - name: Restart PostgreSQL
      listen: restart_service
      ansible.builtin.systemd:
        name: postgresql
        state: restarted
EOT


echo >> /startup.log
echo "startup script running on `date`" >> /startup.log
ansible-playbook -i "localhost," /root/playbook.yaml >> /startup.log 2>&1
