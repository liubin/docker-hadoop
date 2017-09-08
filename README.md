# Hadoop Docker Image

## Highlights
- Supports running hadoop in distributed HA mode.
- Configured using environment variables.

## How to run

### Name node envs:

- `NGINX_PORT`: nginx port to download hdfs conf files(For HBase or other client).Default 9090
- `ACTIVE`: "true", this namenode will be active one.

## Example
Check out the [docker-compose.yml](docker-compose.yml) file to stand up a distributed HA cluster
using docker-compose.
