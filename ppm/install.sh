#!/bin/bash

PPM_VERSION="2022.11.4-20"
R_VERSION="4.3.0"

# Change the below variable assignments to your setup
PPM_LICENSE_KEY="xyz"
PPM_URL="https://ppm.ukhsa.com"
SSL_CERT="/path/to/ssl.cert"
SSL_KEY="/path/to/ssl.key"
DB_HOST="postgres.ukhsa.com"
DB_USER="test"
# Please encrypt the password into a base64 encoded string 
# (e.g. "echo mysecurepassword | base64")
DB_PASSWORD="bXlzZWN1cmVwYXNzd29yZAo="


# The below script will install Posit Package Manager (PPM) 
# into an Ubuntu 20.04 LTS (Focal) AMI. 
# It will use the aforementioned versions of PPM and R. 
# It will expect a folder with sufficient storage to be mounted at /data/rspm. 
# This could be an EFS file system 
# (see https://docs.posit.co/rpm/integration/efs/) or EBS. 

# It will also expect a PostgresDB to be available and accessible (Version > 11)
# (see https://docs.posit.co/rspm/admin/database/#database-postgres)
# The user name and password for both the UsageData DB (rstudio_pm_usage) 
# and normal DB (rstudio_pm) are assumed to be the same 
# and to live on the same RDS host. 

# Prerequisites 

## make deb/ubuntu installs non-interactive
export DEBIAN_FRONTEND=noninteractive

## set proper time zone
apt-get update 
apt-get install -y systemd 
timedatectl set-timezone Europe/London

# Install PPM (Step 1 of https://docs.posit.co/rpm/installation/) 

apt update
apt install -y curl gdebi-core
curl -fO https://cdn.posit.co/package-manager/ubuntu20/amd64/rstudio-pm_${PPM_VERSION}_amd64.deb
gdebi -n rstudio-pm_${PPM_VERSION}_amd64.deb
rm -f rstudio-pm_${PPM_VERSION}_amd64.deb
# https://docs.posit.co/rpm/configuration/ssl-certificates/#configuring-ssl-certificates
setcap 'cap_net_bind_service=+ep' /opt/rstudio-pm/bin/rstudio-pm


# Install R (https://docs.posit.co/resources/install-r/) 
# Note: We also make R the default R version on the system via the "ln" command

curl -O https://cdn.rstudio.com/r/ubuntu-2004/pkgs/r-${R_VERSION}_1_amd64.deb
gdebi -n r-${R_VERSION}_1_amd64.deb
ln -s /opt/R/${R_VERSION}/bin/R /usr/local/bin/R
ln -s /opt/R/${R_VERSION}/bin/Rscript /usr/local/bin/Rscript


# Deploy config file 
# Please note that in the below you will still need to setup and link the SSL ceertificates

cat <<EOF > /etc/rstudio-pm/rstudio-pm.gcfg
[Server]
; Address is a public URL for this Posit Package Manager server. If Package Manager
; is deployed behind an HTTP proxy, this should be the URL for Package Manager in
; terms of that proxy. It must be configured if Package Manager is served from a subdirectory 
like
; `/rspm` to facilitate generating URLs for the `rspm url create` command, Swagger docs,
; and PyPI simple index pages.
;
; Address = https://rstudio-pm.company.com
Address = $PPM_URL
;
; Git sources require a configured R installation. R is often installed at `/usr/lib/R`
; or `/usr/lib64/R`.
RVersion = /opt/R/${R_VERSION}
;
; Customize the data directory if necessary. This is where all packages and metadata are
; stored by default. Refer to Admin Guide for details.
DataDir = /data/rspm

[HTTPRedirect]
Listen = :80

[HTTPS]
Listen = :443
Permanent = true

; SSL Config ==> https://docs.posit.co/rpm/configuration/ssl-certificates/
; Path to a TLS certificate file. If the certificate is signed by a certificate authority, the
; certificate file should be the concatenation of the server's certificate followed by the CA's
; certificate. Must be paired with `HTTPS.Key`.
Certificate = "$SSL_CERT"
;
; Path to a private key file corresponding to the certificate specified with `HTTPS.Certificate`.
; Required when `HTTPS.Certificate` is specified.
Key = "$SSL_KEY"


[CRAN]
; Customize the default schedule for CRAN sync.
SyncSchedule = "0 0 * * *"

[Bioconductor]
; Customize the default schedule for Bioconductor syncs.
SyncSchedule = "0 2 * * *"

[PyPI]
; Customize the default schedule for PyPI syncs.
SyncSchedule = "0 1 * * *"

; Configure Git if you are intending to build and share packages stored in Git repositories.
[Git]
; The amount of time to wait between polling git repos to look for package changes.
PollInterval = 5m
;
; The maximum number of times to attempt building a git package when the build fails.
BuildRetries = 3

[Database]
Provider = postgres

[Postgres]
Password = $DB_PASS
UsageDataPassword = $DB_PASS
URL = "postgres://${DB_USER}@${DB_HOST}/rstudio_pm"
UsageDataURL = "postgres://${DB_USER}@${DB_HOST}/rstudio_pm_usage"

EOF

systemctl restart rspm

#Activating License
/opt/rstudio-pm/bin/license-manager activate $PPM_LICENSE_KEY
systemctl restart rspm 

systemctl status rspm

# https://docs.posit.co/rspm/admin/getting-started/configuration/#quickstart-cran
rspm create repo --name=my-cran --description='CRAN packages'
rspm subscribe --repo=my-cran --source=cran
rspm sync --type=cran

# https://docs.posit.co/rspm/admin/getting-started/configuration/#quickstart-bioconductor
rspm create repo --type=bioconductor --name=bioconductor --description='Bioconductor Packages'
rspm sync --type=bioconductor

# https://docs.posit.co/rspm/admin/getting-started/configuration/#quickstart-pypi-packages
rspm create repo --name=pypi --type=python --description='PyPI packages'
rspm subscribe --repo=pypi --source=pypi
rspm sync --type=pypi
