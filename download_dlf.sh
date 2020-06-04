#!/bin/bash

cd dlf-crawler && ./crawl_dlf.sh && cd ..
ruby download_podcasts.rb download_from_json ./dlf-crawler/dlf.json
