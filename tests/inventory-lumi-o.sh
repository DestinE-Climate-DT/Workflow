#!/usr/bin/env bash
set -e

# Inventory script for LUMI-O buckets
# Runs after the smoke test to gather detailed bucket statistics
# Outputs JSON with name, accessibility, and object count for each bucket

# Extract the [default] section using awk (stops at next section header)
default_section=$(awk '/\[default\]/{p=1;next} /^\[/{p=0} p' ~/.aws/credentials)

AWS_ACCESS_KEY_ID=$(echo "$default_section" |
    grep "aws_access_key_id" |
    cut -d'=' -f2 |
    tr -d ' ')
AWS_SECRET_ACCESS_KEY=$(echo "$default_section" |
    grep "aws_secret_access_key" |
    cut -d'=' -f2 |
    tr -d ' ')

if echo "$default_section" | grep -q "endpoint_url"; then
    AWS_ENDPOINT=$(echo "$default_section" |
        grep "endpoint_url" |
        cut -d'=' -f2 |
        tr -d ' ')
else
    AWS_ENDPOINT="https://lumidata.eu"
fi

sign_request() {
    local resource="$1"
    local dateValue
    dateValue=$(date -R)
    local stringToSign="GET\n\n\n${dateValue}\n${resource}"
    local signature
    signature=$(printf '%s' "${stringToSign}" | openssl sha1 -hmac "${AWS_SECRET_ACCESS_KEY}" -binary | base64)
    echo "${dateValue}|${signature}"
}

list_bucket_objects() {
    local bucket="$1"
    local resource="/${bucket}/"
    local signed
    signed=$(sign_request "$resource")
    local dateValue="${signed%%|*}"
    local signature="${signed##*|}"

    curl --silent --fail \
        -H "Host: ${AWS_ENDPOINT#https://}" \
        -H "Date: ${dateValue}" \
        -H "Authorization: AWS ${AWS_ACCESS_KEY_ID}:${signature}" \
        "${AWS_ENDPOINT}${resource}" 2>/dev/null
}

count_objects() {
    local xml="$1"
    local count
    count=$(echo "$xml" | grep -c "<Key>" 2>/dev/null) || true
    echo "${count:-0}"
}

echo "Gathering LUMI-O bucket inventory..."

# Get bucket list
dateValue=$(date -R)
resource="/"
stringToSign="GET\n\n\n${dateValue}\n${resource}"
signature=$(printf '%s' "${stringToSign}" | openssl sha1 -hmac "${AWS_SECRET_ACCESS_KEY}" -binary | base64)

bucket_xml=$(curl --silent --fail \
    -H "Host: ${AWS_ENDPOINT#https://}" \
    -H "Date: ${dateValue}" \
    -H "Authorization: AWS ${AWS_ACCESS_KEY_ID}:${signature}" \
    "${AWS_ENDPOINT}/")

buckets=$(echo "$bucket_xml" | grep -o "<Name>[^<]*</Name>" |
    sed 's/<Name>//g' |
    sed 's/<\/Name>//g')

# Build JSON array
json_output="["
first=true

for bucket in $buckets; do
    echo "Checking bucket: $bucket"

    accessible=false
    object_count=0

    if bucket_contents=$(list_bucket_objects "$bucket" 2>/dev/null); then
        accessible=true
        object_count=$(count_objects "$bucket_contents")
    fi

    if [ "$first" = true ]; then
        first=false
    else
        json_output+=","
    fi

    json_output+="{\"name\":\"${bucket}\",\"accessible\":${accessible},\"object_count\":${object_count}}"
done

json_output+="]"

echo ""
echo "Bucket inventory:"
echo "$json_output" | jq .

# Export for downstream jobs
echo "LUMI_O_BUCKET_INVENTORY='${json_output}'" >de340-lumi-o-inventory.env
echo ""
echo "Exported LUMI_O_BUCKET_INVENTORY to de340-lumi-o-inventory.env"
