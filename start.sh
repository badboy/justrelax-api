#!/bin/bash

exec bundle exec unicorn \
  --host 127.0.0.1 \
  --port 7001 \
  --env production \
  --config-file unicorn.rb \
  config.ru
