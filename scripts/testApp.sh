#!/bin/bash
set -euxo pipefail

# LMP 3.0+ goals are listed here: https://github.com/OpenLiberty/ci.maven#goals

# Start Pact Broker
cd ..
docker-compose -f "pact-broker/docker-compose.yml" up -d --build

## Build the inventory service
#       package                   - Take the compiled code and package it in its distributable format.
#       liberty:create            - Create a Liberty server.
#       liberty:install-feature   - Install a feature packaged as a Subsystem Archive (esa) to the Liberty runtime.
#       liberty:deploy            - Copy applications to the Liberty server's dropins or apps directory.
cd finish/inventory
mvn -q clean package liberty:create liberty:install-feature liberty:deploy

## Run the integration and publish goal for inventory service
# These commands are separated because if one of the commands fail, the test script will fail and exit.
# e.g if liberty:start fails, then there is no need to run the failsafe commands.
#       liberty:start             - Start a Liberty server in the background.
#       failsafe:integration-test - Runs the integration tests of an application.
#       liberty:stop              - Stop a Liberty server.
#       failsafe:verify           - Verifies that the integration tests of an application passed.
mvn liberty:start
mvn failsafe:integration-test liberty:stop
mvn pact:publish

## Build the system service
cd ../system
mvn -q clean package liberty:create liberty:install-feature liberty:deploy

## Run the integration and publish goal for system service
mvn liberty:start
mvn failsafe:integration-test liberty:stop

## Remove the pact-broker application
cd ../..
docker-compose -f "pact-broker/docker-compose.yml" down
docker rmi postgres:12
docker rmi pactfoundation/pact-broker:2.62.0.0
docker volume rm pact-broker_postgres-volume