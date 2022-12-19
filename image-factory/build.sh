#!/bin/sh -e

cd `dirname $0`

keep_vm=0
for arg in "$@" ; do
    if [ "$arg" == '--keep-vm' ] ; then
        keep_vm=1
    else
        echo "Unsupported flag: ${arg}"
        exit 1
    fi
done

project=`gcloud config get-value project`
region=`gcloud config get-value compute/region`
zone=`gcloud config get-value compute/zone`

log_file='build.log'
rm -f ${log_file}

function log() {
    /bin/echo "$@" | tee -a ${log_file}
}

function log_command() {
    /bin/echo "$@" >> ${log_file}
    "$@" >> ${log_file} 2>&1
}

printf "%-12s %s\n" "project:" "${project}"
printf "%-12s %s\n" "region:" "${region}"
printf "%-12s %s\n" "zone:" "${zone}"
/bin/echo -n "Please answer with yes to proceed with these settings: "
read r
if [ "$r" != 'yes' ] ; then
    exit
fi

version="v`date +%y%m%d%H%M`"
image_family="custom-psql"
image="${image_family}-${version}"
vm_instance=${image}
device_name="db-data"
project_number=`gcloud projects list --filter="${project}" --format='value(PROJECT_NUMBER)'`

# This dependency will change over time
base_image="projects/debian-cloud/global/images/`gcloud compute images list | grep '^debian-11-bullseye-v' | awk '{ print $1 }' | sort | tail -1`"

log "Creating a virtual machine"
log_command gcloud compute instances create ${vm_instance} \
    --machine-type=e2-micro \
    --network-interface=network-tier=STANDARD,subnet=default \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=${project_number}-compute@developer.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
    --create-disk=auto-delete=no,boot=yes,device-name=${vm_instance},image=${base_image},mode=rw,size=10,type=projects/${project}/zones/${zone}/diskTypes/pd-standard \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --reservation-affinity=any

log -n "Waiting for VM to start"
for retry in {60..0} ; do
    /bin/echo -n "."
    if gcloud compute ssh ${vm_instance} --command /bin/true 2> /dev/null ; then
        break
    elif [ $retry -eq 0 ] ; then
        echo
        echo "Failed to connect to ${vm_instance}. Please check https://console.cloud.google.com/compute/instances?project=${project}"
        exit 1
    fi
done
log ""
log "Uploading and running setup script"
log_command gcloud compute scp vm_setup.sh ${vm_instance}:/tmp/setup.sh
log_command gcloud compute ssh ${vm_instance} --command "sudo sh < /tmp/setup.sh"
log_command gcloud compute ssh ${vm_instance} --command "echo ${image} | sudo tee /etc/image-version"

if [ "${keep_vm}" -ne "0" ] ; then
    log "Stopping the VM instead of deleting it. You can clean up manually by running this command:"
    log "  gcloud compute instances delete ${vm_instance}"
    log_command gcloud compute instances stop --quiet ${vm_instance}
else
    log "Deleting VM ${vm_instance}"
    log_command gcloud compute instances delete --quiet ${vm_instance}
fi

log "Creating image ${image}"
log_command gcloud compute images create ${image} \
    --description="PostgreSQL server" \
    --family=${image_family} \
    --source-disk=${vm_instance} \
    --source-disk-zone=${zone} \
    --storage-location=${region}

log "Done!"
