#!/bin/bash

# For every file in tests/schemas, generate a markdown file with the schema
# and the description of the schema

set -xuve

schemas=$(ls tests/schemas/*.schema.json)
for schema in $schemas
do
    # exclude main.schema.json
    if [ $(basename $schema) == "main.schema.json" ]; then
        continue
    fi
    jsonschema-markdown --no-footer $schema > docs/source/schemas/$(basename $schema .schema.json).md    
    # Add a # in the beggining of each file, in the first line
    sed -i '1s/^/#/' docs/source/schemas/$(basename $schema .schema.json).md
done
