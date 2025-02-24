#!/bin/sh

mkdir -p schema-generated ureader ureader-modules
$1./tools/merge-schema.py schema uconfig.yml schema.json

$1./tools/generate-reader.uc schema.json

[ -n "$(which generate-schema-doc)" ] && {
	mkdir -p docs
	generate-schema-doc --config expand_buttons=true schema-generated/schema.json docs/uconfig-schema.html
}
