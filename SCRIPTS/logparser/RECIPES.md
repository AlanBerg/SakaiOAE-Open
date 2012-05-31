Example Bash Script to parse a directory of error logs

```sh
#!/bin/bash
SCRIPTDIR=/home/sakai/jenkins/git/SakaiOAE-Open/SCRIPTS/logparser
echo "Running Report"
/usr/bin/perl ${SCRIPTDIR}/ErrorLogParser.pl --config=${SCRIPTDIR}/qa20-config.yml --ignore_info=1 --ignore_unknown=1 --errordir=/home/sakai/sling/logs
echo "Finished Reports in jenkins/reports/all (without time stamp)".

```
Example Bash Script to parse an error.log

Can run from a crontab.

Places the report in the same directory as the log file. This is helpful for the casual system admin task.

```sh
#!/bin/bash
# Parse error.log
# Can use the dat function to parse a given day, but not sure about the consistency of rotation
SCRIPTDIR=/home/sakai/jenkins/git/SakaiOAE-Open/SCRIPTS/logparser
LOGDIR=/home/sakai/13/sling/logs
ERRORFILE=${LOGDIR}/error.log
ERRORREPORT=${LOGDIR}'/report.'$(date +%F)'.txt'
echo "Running Report => ${ERRORREPORT}"
/usr/bin/perl ${SCRIPTDIR}/ErrorLogParser.pl --config=${SCRIPTDIR}/qa20-config.yml --ignore_info=1 --ignore_unknown=1 --errorfile=${ERRORFILE} > $ERRORREPORT
echo "Finished Report"
```

