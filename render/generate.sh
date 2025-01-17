#!/bin/sh

mkdir -p schema-generated
./tools/merge-schema.py schema uconfig.yml schema.json

./tools/generate-reader.uc schema.json

mkdir -p docs
generate-schema-doc --config expand_buttons=true schema-generated/schema.json docs/uconfig-schema.html

