#!/bin/sh
#
# Copyright (c) 2018, 2019, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#
# This script requires the following environment variables:
#
# JAVA_HOME            - The location of the JDK to use.  The caller must set
#                        this variable to a valid Java 8 (or later) JDK.
#
#
# Build the sample domain home image. You must build the archive file and download the weblogic deploy
# install image prior to executing this shell script.

# parse the ADMIN_HOST, ADMIN_PORT, MS_PORT, and DOMAIN_NAME from the sample properties file and pass
# as a string of --build-arg in the variable BUILD_ARG

echo 'Build the applications...'

if [ -z ${JAVA_HOME} ] || [ ! -e ${JAVA_HOME}/bin/jar ]; then 
   echo "JAVA_HOME must be set to version of a java JDK 1.8 or greater"
   exit 1
fi
echo JAVA_HOME=${JAVA_HOME}

scriptDir="$( cd "$( dirname $0 )" && pwd )"
if [ ! -d ${scriptDir} ]; then
    echo "Unable to determine the sample directory where the application is found"
    echo "Using shell /bin/sh to determine and found ${scriptDir}"
    exit 1
fi

rm -Rf ${scriptDir}/archive
mkdir -p ${scriptDir}/archive/wlsdeploy/applications
mkdir -p ${scriptDir}/archive/wlsdeploy/domainLibraries

echo ' - test webapp...'
cd test-webapp && mvn clean install && cd ..
cp test-webapp/target/testwebapp.war ${scriptDir}/archive/wlsdeploy/applications/testwebapp.war

echo ' - logging exporter...'
wget -O ${scriptDir}/archive/wlsdeploy/domainLibraries/weblogic-logging-exporter-0.1.jar \
     https://github.com/oracle/weblogic-logging-exporter/releases/download/v0.1/weblogic-logging-exporter-0.1.jar

wget -O ${scriptDir}/archive/wlsdeploy/domainLibraries/snakeyaml-1.23.jar \
     http://repo1.maven.org/maven2/org/yaml/snakeyaml/1.23/snakeyaml-1.23.jar

echo ' - metrics exporter...'
rm -rf weblogic-monitoring-exporter
git clone https://github.com/oracle/weblogic-monitoring-exporter
cd weblogic-monitoring-exporter
mvn clean install 
cd webapp
mvn clean package -Dconfiguration=../../exporter-config.yaml
cd ../..
cp weblogic-monitoring-exporter/webapp/target/wls-exporter.war \
   ${scriptDir}/archive/wlsdeploy/applications/wls-exporter.war

echo 'Build the WDT archive...'
rm archive.zip
${JAVA_HOME}/bin/jar cvf ${scriptDir}/archive.zip  -C ${scriptDir}/archive wlsdeploy

echo 'Download WDT...'
wget -O weblogic-deploy.zip \
     https://github.com/oracle/weblogic-deploy-tooling/releases/download/weblogic-deploy-tooling-0.20/weblogic-deploy.zip

echo 'Build the domain image...'
container-scripts/setEnv.sh properties/docker-build/domain.properties

docker build \
    $BUILD_ARG \
    --build-arg WDT_MODEL=simple-topology.yaml \
    --build-arg WDT_VARIABLE=properties/docker-build/domain.properties \
    --build-arg WDT_ARCHIVE=archive.zip \
    --force-rm=true \
    -t my-domain1-image:1.0 .

