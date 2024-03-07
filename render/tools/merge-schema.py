#!/usr/bin/env python3

import sys
import yaml
import json

def schema_filename(list):
    file = list.split("v1/")
    file.pop(0)
    return file[0].replace("/", ".") + "yml"

def entity_name(uri):
    name = uri.replace("https://uconfig.openwrt.org/schema/v1/", "").rstrip("/")
    return name.replace("/", ".")

def schema_load(filename):
    print(sys.argv[1] + "/" + filename)
    with open(sys.argv[1] + "/" + filename) as stream:
        try:
            schema = yaml.safe_load(stream)
            return schema
        except yaml.YAMLError as exc:
            print(exc)

def schema_compile(input, output, definitions):
    for k in input:
        if isinstance(input[k], dict):
            if k not in output:
                output[k] = {}
            schema_compile(input[k], output[k], definitions)
        elif k == "$ref" and input[k].startswith("https://"):
            name = entity_name(input[k])
            compiled = schema_compile(schema_load(schema_filename(input[k])), {}, definitions)
            definitions[name] = compiled
            output["$ref"] = "#/$defs/{}".format(name)
        elif k == "$ref":
            output["properties"] = {"reference": {"type": "string"}}
        elif k == "anyOf" or k == "oneOf" or k == "allOf":
            r = []
            for v in input[k]:
                o = {}
                schema_compile(v, o, definitions)
                r.append(o)
            output[k] = r
        else:
            output[k] = input[k]
    return output

def schema_generate():
    with open(sys.argv[3], 'w') as outfile:
        defs = {}
        schema = schema_compile(schema_load(sys.argv[2]), {}, defs)
        schema["$defs"] = defs
        json.dump(schema, outfile, ensure_ascii = True, indent = 8)

if len(sys.argv) != 4:
    raise Exception("Invalid parameters");

schema_generate()
