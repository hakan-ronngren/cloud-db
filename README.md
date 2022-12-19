# cloud-db

## Cloud SQL databases at a monthly cost of one hamburger meal

The rationale of this project is that I want to use SQL databases for my hobby projects without paying enterprise-level money for them. I want one single database server VM that can hold the databases of all applications I run. I do not need redundancy, because if my server goes down I will just create it again and restore its state from a backup file that I fetch from a bucket.

I would be the only user, and the amounts of data would not be petabytes, not even terabytes, but rather gigabytes at most. Let's set a budget of US$ 10 each month, roughly the price of a hamburger meal somewhere.

These are the options I explored. All are in the Google Cloud Platform because that's what I use. All costs are calculated with the [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator). I want 10 GiB of storage and 100 GiB backup capacity, and I would insert data at a monthly pace of 10 MiB and read 1 GiB. for fair comparison I want the service to be available 24/7.

| Alternative | Price/month | Observations |
| --- | --- | --- |
| [BigQuery](https://cloud.google.com/bigquery) | US$ 0 | Cheap, but don't let this fool you. BigQuery is undoubtedly excellent as a backend for dashboards visualizing petabytes of analytics data that flows out of your business like water from a fire hose. However it is deliberatly not designed for, and therefore not useful for regular application databases. The [CREATE TABLE](https://cloud.google.com/bigquery/docs/reference/standard-sql/data-definition-language#create_table_statement) statement does not allow you to specify a unique constraint, to mention one thing. |
| [Cloud SQL](https://cloud.google.com/sql) | US$ 18 | An excellent choice from a techical perspective, the price is still over my hamburger budget even if I use the cheapest instance type, a db-f1-micro shared instance. |
| SQLite + [Filestore](https://cloud.google.com/filestore) | US$ 205 | Originally a C library, SQLite has been ported to several other ecosystems. I would use the [Python](https://docs.python.org/3/library/sqlite3.html) one. Because it is an in-process database solution, I would not even have to run a separate database server. All I would need is a persistent disk to store my `sqlite.db` file. This is where Filestore would come into play. However, Google won't sell me portions I can eat. The minimum storage of 1024 GiB would exhaust my monthly budget in two days. |

I was optimistic about the last option, but it turned out that it was by far the worst choice among the three. This is why I decided to wire my own solution.

I navigated to (Compute Engine | VM instances)[https://console.cloud.google.com/compute] and clicked on CREATE INSTANCE. Going for the budget options all the way, these were the prices I got for a VM in the us-central1 region at the time of writing:

| Item | Monthly estimate |
| --- | --- |
| e2-micro (2 vCPU + 1 GB memory) | $6.11 |
| 10 GB standard persistent disk (boot) | $0.40 |
| 10 GB standard persistent disk (data) | $0.40 |
| __Total__ | __$6.91__ |

If I used an f1-micro with 1 vCPU and 614 MB memory, the price would go down to $4.68 a month, but this might even be too small.

The separate data disk would allow me to recreate the VM at any time to upgrade it.

## Tools you'll need

* [GNU Make](https://www.gnu.org/software/make/) to build the image. Alternatively, you can run the commands in the Makefile yourself.
* [terraform](https://www.terraform.io) to turn the code in this repo into working infrastructure
* [gcloud](https://cloud.google.com/cli) to interact with your GCP resources

## Configure your environment

You need a GCP project, so either create one using the [console](https://console.cloud.google.com/) or run whatever infrastructure code you usually use to create projects. You also need to decide on a [region and a zone](https://cloud.google.com/compute/docs/regions-zones) where your PostgreSQL server will run. Then run these commands in a shell:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <your-project-id-incl-digits>
gcloud config set compute/region <your-region>
gcloud config set compute/zone <your-zone>
```

## Create a PostgreSQL server image

Your server will start from an [image](https://console.cloud.google.com/compute/images), backed by a [disk](https://console.cloud.google.com/compute/disks) in your project. This script that will create it for you:

```bash
image-factory/build.sh
```

## Start a test VM

The `test-local` directory contains Terraform code to include this module locally. Just create a copy of `main.tf.template` called `main.tf`, and edit it to suit your setup. Then you can run these commands to start up a test instance:

```bash
cd test-local
terraform init
terraform apply
```

Even though it is not directly exposed to the Internet, you can connect to it with ssh through a tunnel:

```bash
gcloud compute ssh "db-vm" --tunnel-through-iap
```



GCP networking fundamentals
* https://www.networkmanagementsoftware.com/google-cloud-platform-gcp-networking-fundamentals/

Would probably need VPC network peering to restrict access
* https://cloud.google.com/vpc/docs/vpc-peering
* https://cloud.google.com/run/docs/configuring/connecting-vpc

Pretty good intro on setting up postgres
* https://linuxize.com/post/how-to-install-postgresql-on-debian-10/
