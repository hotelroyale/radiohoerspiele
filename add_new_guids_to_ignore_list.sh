#!/bin/bash

cp ignore_podcast_guids ignore_podcast_guids.$(date +"%Y-%m-%d_%H-%m-%S").backup
ruby all_guids.rb|uniq -u > ignore_podcast_guids.tmp
mv ignore_podcast_guids.tmp ignore_podcast_guids
