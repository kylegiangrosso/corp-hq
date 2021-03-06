#!/bin/bash

CORPHQ_BEHAVE_SLEEP="${CORPHQ_BEHAVE_SLEEP:-2}"
echo "-----------"
echo "Behaviorial tests running with a sleep value of $CORPHQ_BEHAVE_SLEEP seconds."
echo "To change this value set the 'CORPHQ_BEHAVE_SLEEP' environment variable."
echo "-----------"
echo ""

# Just make sure the containers are being build fresh
docker-compose -f test-compose.yml down -v
docker rm test-node -v

echo ""
echo "-----------"
echo "Build the applications before we create docker images for them."
echo "-----------"
dotnet publish --configuration Release ./app/api
dotnet publish --configuration Release ./app/runner
dotnet publish --configuration Release ./app/manager

echo "-----------"
echo "Build the images we will eventually test."
echo "-----------"
docker-compose -f test-compose.yml build

echo "-----------"
echo "Start the db and dependencies."
echo "-----------"
docker-compose -f test-compose.yml up -d test-mongodb test-rabbitmq test-eve-api

echo "-----------"
echo "Sleeping $CORPHQ_BEHAVE_SLEEP seconds then seed the db with test data."
echo "-----------"
sleep $CORPHQ_BEHAVE_SLEEP
docker exec -it test-mongodb mongo 127.0.0.1:27017/corp-hq /var/scripts/test-seed-data.js

echo "-----------"
echo "Sleeping $CORPHQ_BEHAVE_SLEEP seconds then starting the tested services."
echo "-----------"
sleep $CORPHQ_BEHAVE_SLEEP
docker-compose -f test-compose.yml up -d test-runner test-runner-2 test-manager test-api

echo "-----------"
echo "Sleeping $CORPHQ_BEHAVE_SLEEP seconds then starting the tests."
echo "-----------"
sleep $CORPHQ_BEHAVE_SLEEP
docker run -it -v $(pwd)/tests/behavior:/home/node/app -w="/home/node/app" -e CORPHQ_BEHAVE_STEP_TIMEOUT=$CORPHQ_BEHAVE_STEP_TIMEOUT --network="test-network" --name test-node node:8 bash -c "npm install; API_URL=http://test-api:5000 MONGO_URL=mongodb://test-mongodb:27017/auth npm run cucumber -- --tags 'not @ignore'"
EXIT_CODE="$(docker inspect --format='{{.State.ExitCode}}' test-node)"
docker rm test-node -v

echo "-----------"
echo "Shutdown the services and clean up dangling volumes."
echo "-----------"
if [ "$1" = "debug" ] && [ "$EXIT_CODE" != "0" ]; then
    echo "Not cleaning up containers or volumes since debug mode is on and there was an error. Run 'docker-compose -f test-compose.yml down -v' to clean up containers."
else
    docker-compose -f test-compose.yml down -v
fi

# Helpful commands for debugging.
# docker logs test-runner
# docker exec -it test-mongodb mongo
# docker run -it --rm -v $(pwd)/tests/mock-services/eve-api:/var/mock-scripts -w="/var/mock-scripts" -p 3000:3000 --name test-eve-api node:8 bash -c "npm install; node server.js"
# docker volume rm $(docker volume ls -qf dangling=true)
# docker system prune -f --volumes

echo ""
echo "EXIT_CODE: $EXIT_CODE"
if [ "$EXIT_CODE" = "0" ]; then
    exit 0
else
    exit 1
fi