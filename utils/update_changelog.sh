#!/bin/bash

git for-each-ref \
    --sort=-creatordate \
    --format '## %(refname) (Released %(creatordate))

%(if)%(subject)%(then)%(subject)%0a%(if)%(body)%(then)%0a%(end)%(end)%(if)%(body)%(then)%(body)%0a%(end)' \
    refs/tags |
    sed 's#refs/tags/##g'
