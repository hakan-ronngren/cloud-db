# cloud-db

## Cloud SQL databases at the monthly cost of one hamburger meal

The rationale of this project is that I want to use SQL databases for my hobby projects without paying enterprise-level money for them. I want one single database server VM that can hold the databases of all applications I run. I do not need redundancy, because if my server goes down I will just create it again and restore its state from a backup file that I fetch from a bucket.

I would be the only user, and the amounts of data would not be petabytes, not even terabytes, but rather gigabytes at most. Let's set a budget of US$ 10 each month, roughly the price of a hamburger meal somewhere.

These are the options I explored. All are in the Google Cloud Platform because that's what I use. All costs are calculated with the [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator). I want 10 GiB of storage and 100 GiB backup capacity, and I would insert data at a monthly pace of 10 MiB and read 1 GiB. for fair comparison I want the service to be available 24/7.

| Alternative | Price/month | Observations |
| --- | --- | --- |
| [BigQuery](https://cloud.google.com/bigquery) | ~ US$ 0 | Cheap, but don't let this fool you. BigQuery is undoubtedly excellent as a backend for dashboards visualizing petabytes of analytics data that flows out of your business like water from a fire hose. However it is deliberately not designed for, and therefore also not particularly useful for regular application databases. You can't have a unique constraint for a column, to mention one thing. |
| [Cloud SQL](https://cloud.google.com/sql) | US$ 18 | An excellent choice from a technical perspective, the price is still over my hamburger budget even if I use the cheapest instance type, a db-f1-micro shared instance. |
| SQLite + [Filestore](https://cloud.google.com/filestore) | US$ 205 | Originally a C library, SQLite has been ported to several other ecosystems. Because SQLite is an in-process database solution, I would not even have to run a separate database server. All I would need is a persistent disk to store my `sqlite.db` file. This is where Filestore would come into play. However, Google won't sell me portions I can eat. The minimum storage of 1024 GiB would eat my monthly budget in less than two days. |

I was optimistic about the last option, but it turned out that it was by far the worst choice among the three.

So I decided to wire my own solution. I navigated to [Compute Engine | VM instances](https://console.cloud.google.com/compute) and clicked on CREATE INSTANCE. Going for the budget options all the way, these were the prices I got for a VM in the us-central1 region at the time of writing:

| Item | Monthly estimate |
| --- | --- |
| e2-micro (2 vCPU + 1 GB memory) | $6.73 |
| 10 GB standard persistent disk (boot) | $0.40 |
| 10 GB standard persistent disk (data) | $0.40 |
| __Total__ | __$7.13__ |

The separate data disk would allow me to recreate the VM at any time to upgrade it.

## UNDER CONSTRUCTION

This is still a work in progress. Next up is to decide exactly how to connect to the DB from, say, Cloud Run.

I could use a [serverless VPC access connector](https://cloud.google.com/run/docs/configuring/connecting-vpc) to allow Cloud Run to call this VM, but unfortunately, this connector would have to run on additional VMs that I do not want to pay for.

Instead, I want to use some as-a-service solution. There is one: IAP. I already reach my VM with `gcloud compute ssh db-vm --tunnel-through-iap`. As always with SSH, I can also set up port forwarding so that I can reach the PostgreSQL port on the VM through a local port on my machine. Maybe I could use that mechanism from a Cloud Run service as well.

Another alternative would be to use PubSub as a bridge, to send queries in one direction and results in the other. This option feels a bit awkward, and I am not sure about what latency I would get.

## Tools you'll need

* [terraform](https://www.terraform.io) to turn the code in this repo into working infrastructure
* [gcloud](https://cloud.google.com/cli) to interact with your GCP resources

## Configure your environment

You need a GCP project, so either create one using the [console](https://console.cloud.google.com/) or run whatever infrastructure code you usually use to create projects. You also need to decide on a [region and a zone](https://cloud.google.com/compute/docs/regions-zones) where your PostgreSQL server will run. Then run these commands in a shell:

```
gcloud auth login
gcloud auth application-default login
gcloud config set project <your-project-id-incl-digits>
gcloud config set compute/region <your-region>
gcloud config set compute/zone <your-zone>
```

## Create a PostgreSQL server image

Your server will start from an [image](https://console.cloud.google.com/compute/images), backed by a [disk](https://console.cloud.google.com/compute/disks) in your project. This script will create it for you:

```
image-factory/build.sh
```

## Start a test VM from this repository

The `test-local` directory contains Terraform code to include this module locally. Just create a copy of [main.tf.template](test-local/main.tf.template) called `main.tf`, and edit it to suit your setup. Then you can run these commands to start up a test instance:

```
cd test-local
source ./sourceme
terraform init
terraform apply
```

> The first time you apply, the operation might fail with a message saying that a Compute Engine System service account is lacking the permissions to start and stop instances. There is code in this project to fix this issue, but it may take a couple of minutes until this code takes effect, and during that time your apply commands may fail. Just give GCP a couple of minutes and try again.

Even though the VM is not directly exposed to the Internet, you can connect to it with ssh through a tunnel:

```
db-vm
```

If you kept the _foo_ database definition in your `databases` argument, you can then connect to the database:

```
psql -U foo -h localhost
```

Having the `psql` client on your local machine, you can also set up a tunnel in one shell:

```
psql-localhost-5432
```

... and run `psql` in another one:

```
psql -U foo -h localhost
```

If you enable the [pgAdmin](https://www.pgadmin.org/) application (see the [variables.tf](variables.tf) file), you can reach it through an IAM tunnel like this:

```
pgadmin-localhost-8888
```

You can then browse to http://localhost:8888/, click on PostgreSQL under Servers in the left panel, and log on as _pgadmin_ with password _pgadmin_.

This web UI is exposed only locally inside the VM, so there is no other way to reach it than through this tunnel.

After having run `terraform apply`, you can log on to the machine quite soon, but the machine is still running `ansible-playbook` for a while to set itself up. If you follow the startup log (`tail -f /startup.log`) on the VM, you will know that it is done when you see the play recap message. Then just exit with `ctrl-C`.

The playbook is located in the `/root` directory and will run each time the machine boots, even though it would usually not change anything after the first time. If there is a failure, you can use it to troubleshoot and fix the problem:

```
sudo -i
ansible-playbook -i "localhost," /root/playbook.yaml
```

## Use the module from your application terraform code

You would use the module just like the code in the `test-local` directory does, but rather than including it from a local directory you would write `source = git::ssh://git@github.com/hakan-ronngren/cloud-db.git` or your own fork if you have one.

## Good to know

You can mark the db-vm as tainted to force the next `terraform apply` to recreate it:

```
terraform taint module.db_vm.google_compute_instance.db_vm
```

## For image developers

If pass the `--keep-vm` flag to the build script, the VM is stopped rather than deleted before the image is created. You can then start it and experiment with it.

## Misc links

GCP networking fundamentals

* https://www.networkmanagementsoftware.com/google-cloud-platform-gcp-networking-fundamentals/

Ansible PostgreSQL modules

* https://docs.ansible.com/ansible/latest/collections/community/postgresql/index.html
