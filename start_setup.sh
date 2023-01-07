#!/bin/bash

docker-compose down -v
rm -rf ./conf-master/data
rm -rf ./conf-slave/data
docker-compose build
docker-compose up -d

until docker exec mysql_master sh -c 'export MYSQL_PWD=root; mysql -u root -e ";"'
do
    echo "WAITING TO GET mysql_master database connection..."
    sleep 4
done

master_statement='CREATE USER "movie_catalogue_user_slave"@"%" IDENTIFIED BY "passpass123"; GRANT REPLICATION SLAVE ON *.* TO "movie_catalogue_user_slave"@"%"; FLUSH PRIVILEGES;'
docker exec mysql_master sh -c "export MYSQL_PWD=root; mysql -u root -e '$master_statement'"

until docker exec mysql_slave sh -c 'export MYSQL_PWD=root; mysql -u root -e ";"'
do
    echo "WAITING TO GET mysql_slave database connection..."
    sleep 4
done

MASTER_STATUS_STATEMENT=`docker exec mysql_master sh -c 'export MYSQL_PWD=root; mysql -u root -e "SHOW MASTER STATUS"'`
MASTER_LOG_FILE=`echo $MASTER_STATUS_STATEMENT | awk '{print $6}'`
MASTER_POS=`echo $MASTER_STATUS_STATEMENT | awk '{print $7}'`

# echo "MASTER STATUS STATEMENT | $MASTER_STATUS_STATEMENT"
# echo "MASTER LOG FILE | $MASTER_LOG_FILE"
# echo "MASTER POS | $MASTER_POS"

# START_SLAVE_STATEMENT="CHANGE MASTER TO MASTER_HOST='mysql_master',MASTER_USER='movie_catalogue_user_slave',MASTER_PASSWORD='passpass123',MASTER_LOG_FILE='$MASTER_STATUS_STATEMENT',MASTER_LOG_POS=$MASTER_POS; START SLAVE;"
START_SLAVE_STATEMENT="CHANGE MASTER TO MASTER_HOST='mysql_master',MASTER_USER='movie_catalogue_user_slave',MASTER_PASSWORD='passpass123',MASTER_LOG_FILE='$MASTER_LOG_FILE',MASTER_LOG_POS=$MASTER_POS; START SLAVE;"
START_SLAVE_COMMAND='export MYSQL_PWD=root; mysql -u root -e "'
START_SLAVE_COMMAND+="$START_SLAVE_STATEMENT"
START_SLAVE_COMMAND+='"'
echo "EXECUTING START SLAVE COMMAND"
docker exec mysql_slave sh -c "$START_SLAVE_COMMAND"

docker exec mysql_slave sh -c "export MYSQL_PWD=root; mysql -u root -e 'SHOW SLAVE STATUS \G'"