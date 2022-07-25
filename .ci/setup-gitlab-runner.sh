#!/bin/bash
set -euo pipefail
set -x

# 1. Install Docker.
#    Ubuntu: sudo apt install docker
#
# 2. Install GitLab Runner.
#    Ubuntu: https://docs.gitlab.com/runner/install/linux-repository.html#installing-the-runner
#
# 3. (Optional) Enable on startup
#    sudo systemctl enable gitlab-runner
#
# 4. start / stop / restart
#    sudo systemctl start gitlab-runner
#    sudo systemctl stop gitlab-runner
#    sudo systemctl restart gitlab-runner
#

# Number of CPUs to limit a docker instance to
NCPUS=4

# Number of runners to use. Each runner will get NCPUS
NRUNNERS=1

# Get this key from https://gitlab.com/groups/clash-lang/-/runners
# under "Register a group runner".
REGISTER_KEY=XXXXXXXXXXXXXXXXX

# Points to a MINIO instance. If you're in the office, use the cache on
# diepenheim. You can retrieve the CACHE_ACCESS_KEY and CACHE_SECRET_KEY
# from /etc/gitlab-runner/config.toml.
CACHE_IP=localhost
CACHE_ACCESS_KEY=YYYYYYYYYYYYYY
CACHE_SECRET_KEY=ZZZZZZZZZZZZZZ

sudo gitlab-runner register \
  -r ${REGISTER_KEY} \
  -u https://gitlab.com/ \
  --docker-cpus ${NCPUS} \
  --cache-path cache \
  --cache-type s3 \
  --cache-shared \
  --cache-s3-server-address ${CACHE_IP}:9000 \
  --cache-s3-access-key ${CACHE_ACCESS_KEY} \
  --cache-s3-secret-key ${CACHE_SECRET_KEY} \
  --cache-s3-bucket-name runner \
  --cache-s3-insecure \
  --docker-image alpine:latest \
  --limit ${NRUNNERS} \
  --executor docker \
  -n \
  --tag-list $(hostname),local \
  --name $(hostname)
