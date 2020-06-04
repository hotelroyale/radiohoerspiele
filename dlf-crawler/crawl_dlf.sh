#!/bin/bash

mv dlf.json dlf-$(date +"%Y-%m-%d_%H-%m-%S").json && node extract_audio.js > dlf.json

