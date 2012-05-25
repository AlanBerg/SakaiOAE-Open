#!/bin/bash
export JAVA_OPTS="-server -d64 -Xms4048m -Xmx4048 -XX:MaxPermSize=512m" 
export FINDBUGS_HOME=/home/alan/Desktop/SAKIOAE/findbugs-2.0.1-rc2
$FINDBUGS_HOME/bin/findbugs -textui -maxHeap 2512 -longBugCodes -experimental -xml:withMessages -outputFile /home/alan/Desktop/SAKIOAE/oae.xml  /home/alan/Desktop/SAKIOAE/FINDBUGS
