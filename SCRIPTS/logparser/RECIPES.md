Example Bash Script to parse a directory of error logs

```sh
#!/bin/bash
SCRIPTDIR=/home/sakai/jenkins/git/SakaiOAE-Open/SCRIPTS/logparser
echo "Running Report"
/usr/bin/perl ${SCRIPTDIR}/ErrorLogParser.pl --config=${SCRIPTDIR}/qa20-config.yml --ignore_info=1 --ignore_unknown=1 --errordir=/home/sakai/sling/logs
echo "Finished Reports in jenkins/reports/all (without time stamp)".
```

