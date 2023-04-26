#!/bih/bash

# Prerequisites: curl command 
apt-get update && apt-get install -y curl

# First, let's get the rspm cli and the offline downloader (https://docs.posit.co/rpm/installation/#download-and-install-the-standalone-cli) 

# rspm cli
RSPM_SERVER_VERSION=2022.11.4-20
curl -o rspm -f https://cdn.posit.co/package-manager/linux/amd64/rspm-cli-linux-${RSPM_SERVER_VERSION}
chmod +x rspm
mv rspm /usr/local/bin

# rspm offline-downloader
curl -o rspm-offline-downloader -f https://cdn.posit.co/package-manager/linux/amd64/rspm-offline-downloader-linux-$RSPM_SERVER_VERSION
chmod +x rspm-offline-downloader
mv rspm-offline-downloader /usr/local/bin

# run the download(s)

## start with CRAN (https://cran.r-project.org/web/packages/index.html) 
rspm-offline-downloader  get  cran --linux-distros focal --r-versions 4.2 --include-binaries --destination /data/rspm-offline/cran --rspm-version $RSPM_SERVER_VERSION

## next is Bioconductor (https://www.bioconductor.org/) 
rspm-offline-downloader  get  bioconductor --destination /data/rspm-offline/bioconductor --rspm-version $RSPM_SERVER_VERSION 

## Pypi is not (yet) supported for offline usage. 


