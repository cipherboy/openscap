#!/bin/bash

docker build --tag openscap:add-docker-repo -f Dockerfile .
docker run openscap:add-docker-repo
