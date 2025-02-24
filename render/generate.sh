#!/bin/sh

mkdir -p ${1}schema-generated ${1}ureader ${1}ureader-modules
${1}tools/merge-schema.py ${1}schema uconfig.yml ${1}schema-generated/schema.json

${1}tools/generate-reader.uc ${1}

[ -n "$(which generate-schema-doc)" -a -z "$1" ] && {
	mkdir -p docs
	generate-schema-doc --config expand_buttons=true schema-generated/schema.json docs/uconfig-schema.html
}
exit 0
