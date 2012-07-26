export DISPLAY=":20"
mvn clean integration-test -Dlog4j.configuration=file:./src/test/resources/log4j.properties -DSTARTURL=https://qa20-us.sakaiproject.org:8088 -DSUITE=src/test/resources/selenium/SmokeTests.xhtml
