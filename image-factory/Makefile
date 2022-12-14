.PHONY: image

# To get this file, first run:
# terraform apply -auto-approve -var="install_from_base_image=true"
include terraform-generated.mk

IMAGE_NAME = $(IMAGE_FAMILY)-v$(shell date +%y%m%d%H%M)

image:
	: Check the console
	: https://console.cloud.google.com/compute/instances
	: Press ENTER here when the VM is running
	@read x
	gcloud compute instances stop --project $(PROJECT) --zone $(ZONE) db-vm
	gcloud compute images create $(IMAGE_NAME)-temp \
		--project $(PROJECT) \
		--source-disk=db-vm \
		--source-disk-zone=$(ZONE) \
		--storage-location=$(REGION)
	gcloud compute images create $(IMAGE_NAME) \
		--family=$(IMAGE_FAMILY) \
		--project=$(PROJECT) \
		--source-image=$(IMAGE_NAME)-temp \
		--guest-os-features="UEFI_COMPATIBLE" \
		--storage-location=$(REGION)
	echo y | gcloud compute images delete $(IMAGE_NAME)-temp \
		--project $(PROJECT)
	: $(IMAGE_NAME) was successfully created in $(REGION). You may now run terraform destroy.

ssh:
	gcloud compute ssh --zone $(ZONE) "db-vm" --project $(PROJECT)
