#!/bin/bash

# Assumes cd'ed into project directory
# Only a POC so no checks yet or beautifying
#DEPLOY SERVER
#wget https://sakai-oae.ci.cloudbees.com/job/org.sakaiproject.nakamura-incremental-build/ws/app/target/org.sakaiproject.nakamura.app-1.4.0-SNAPSHOT.jar


ERROR_LOG=/home/berg/oae/tar/sling/logs/error.log
JAVA_HOME=/home/berg/jdk1.6.0_32
HOST=localhost
PORT=8080
MAVEN_HOME=/usr/local/maven-2.2.1
MAVEN_CMDS=verify
#MAVEN_CMDS=
WWW=/home/sakaiqa/whatsnew_bugs/www/PERFORMANCE
YEAR=`date +%y`
MONTH=`date +%B`
DAY=`date +%d`
HOURMINUTE=`date +%R`
WWW_HOME=${WWW}/${YEAR}/${MONTH}/${DAY}/${HOURMINUTE}

echo Running Jmeter tests
export JAVA_HOME=${JAVA_HOME}

# Clean up if needed
rm telemetry*
${MAVEN_HOME}/bin/mvn clean

mkdir -p ${WWW_HOME}/results
date > ${WWW_HOME}/date.txt
cp src/test/jmeter/user.properties ${WWW_HOME}/user.properties
cp index.html ${WWW_HOME}/index.html
wget ${HOST}:${PORT}/system/telemetry
mv ./telemetry ${WWW_HOME}/telemetry.before.xml
${MAVEN_HOME}/bin/mvn ${MAVEN_CMDS} > ${WWW_HOME}/maven.log.txt
wget ${HOST}:${PORT}/system/telemetry
mv ./telemetry ${WWW_HOME}/telemetry.after.xml
cp target/* ${WWW_HOME}
cp target/jmeter/results/* ${WWW_HOME}/results
ln -s ${WWW_HOME} ${WWW}/last 
# soft links dont always work with Apache so
mkdir ${WWW}/jenkins_pickup
rm ${WWW}/jenkins_pickup/*
cp target/jmeter/results/* ${WWW}/jenkins_pickup
rm ${WWW}/last.error.log
cp ${ERROR_LOG} ${WWW}/last.error.log
