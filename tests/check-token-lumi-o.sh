#!/usr/bin/env bash
set -e

# [NOTE] PG: For the future: check also rclone, etc.
#            In a minimal case, this should fire off
#            an auth check for the same "method" as
#            is used in the workflow. For now, just
#            curl the endpoint and check you get back
#            a 200 response code and list the buckets
#
# This check follows recommendations of:
# https://gitlab.earth.bsc.es/digital-twins/de_340-2/workflow/-/issues/1128
echo "Checking AWS credentials file..."
if [ ! -f ~/.aws/credentials ]; then
    echo "ERROR: ~/.aws/credentials file not found"
    exit 1
fi
echo "AWS credentials file exists"

# [NOTE] PG: I do not really like this being in the
#            [default] section, I would instead suggest
#            that this is more explicit for LUMI-O
#
#            ... i.e. what the LUMI Portal suggests in
#            its generated snippets
#
# Accept either [default] or [development] — pass if either is present.
if grep -q "\[default\]" ~/.aws/credentials; then
    SECTION="default"
    echo "Found [default] section in ~/.aws/credentials"
elif grep -q "\[development\]" ~/.aws/credentials; then
    SECTION="development"
    echo "Found [development] section in ~/.aws/credentials"
else
    echo "ERROR: neither [default] nor [development] section found in ~/.aws/credentials"
    exit 1
fi

# Extract the chosen section using awk (stops at next section header)
default_section=$(awk "/\\[$SECTION\\]/{p=1;next} /^\\[/{p=0} p" ~/.aws/credentials)

if ! echo "$default_section" | grep -q "aws_access_key_id"; then
    echo "ERROR: aws_access_key_id not found in [$SECTION] section"
    exit 1
fi

if ! echo "$default_section" | grep -q "aws_secret_access_key"; then
    echo "ERROR: aws_secret_access_key not found in [$SECTION] section"
    exit 1
fi

echo "AWS credentials format looks good"

echo "Testing AWS credentials..."
# endpoint_url may live in ~/.aws/credentials OR ~/.aws/config.
# In ~/.aws/config, non-default profiles use "profile <name>" headers,
# e.g. [profile development], while [default] stays as [default].
AWS_ENDPOINT=""
if echo "$default_section" | grep -q "endpoint_url"; then
    AWS_ENDPOINT=$(echo "$default_section" |
        grep "endpoint_url" |
        cut -d'=' -f2 |
        tr -d ' ')
    echo "Found endpoint_url in ~/.aws/credentials"
elif [ -f ~/.aws/config ]; then
    # Match [default] or [profile <SECTION>] in config
    if [ "$SECTION" = "default" ]; then
        config_header="default"
        config_section=$(awk '/\[default\]/{p=1;next} /^\[/{p=0} p' ~/.aws/config)
    else
        config_header="profile ${SECTION}"
        config_section=$(awk "/\\[profile ${SECTION}\\]/{p=1;next} /^\\[/{p=0} p" ~/.aws/config)
    fi
    if echo "$config_section" | grep -q "endpoint_url"; then
        AWS_ENDPOINT=$(echo "$config_section" |
            grep "endpoint_url" |
            cut -d'=' -f2 |
            tr -d ' ')
        echo "Found endpoint_url in ~/.aws/config [${config_header}]"
    fi
fi

if [ -n "$AWS_ENDPOINT" ]; then
    echo "Auto-detected endpoint: ${AWS_ENDPOINT}"
    echo "Checking endpoint: $AWS_ENDPOINT"

    # See https://docs.lumi-supercomputer.eu/storage/lumio/clients-general/#raw-http-request
    AWS_ACCESS_KEY_ID=$(echo "$default_section" |
        grep "aws_access_key_id" |
        cut -d'=' -f2 |
        tr -d ' ')
    AWS_SECRET_ACCESS_KEY=$(echo "$default_section" |
        grep "aws_secret_access_key" |
        cut -d'=' -f2 |
        tr -d ' ')

    echo "Testing AWS credentials by listing buckets with curl..."
    dateValue=$(date -R)
    resource="/"
    stringToSign="GET\n\n\n${dateValue}\n${resource}"
    # HMAC signing requires the secret key in a variable briefly; unset immediately after use.
    signature=$(printf '%s' "${stringToSign}" | openssl sha1 -hmac "${AWS_SECRET_ACCESS_KEY}" -binary | base64)
    unset AWS_SECRET_ACCESS_KEY

    if curl --silent --fail \
        -H "Host: ${AWS_ENDPOINT#https://}" \
        -H "Date: ${dateValue}" \
        -H "Authorization: AWS ${AWS_ACCESS_KEY_ID}:${signature}" \
        "${AWS_ENDPOINT}/" >./lumio-bucket-list 2>&1; then
        echo "SUCCESS: AWS credentials for LUMI-O are valid and authenticated"
        echo ""
        echo "Available buckets:"
        grep -o "<Name>[^<]*</Name>" ./lumio-bucket-list |
            sed 's/<Name>//g' |
            sed 's/<\/Name>//g' |
            while read -r bucket; do
                echo "  - $bucket"
            done
        rm ./lumio-bucket-list
    else
        echo "ERROR: AWS credentials authentication failed - cannot access S3 service"
        echo "Endpoint used: ${AWS_ENDPOINT}"
        echo "Please check:"
        echo "  1. Your keys are correct and not expired (regenerate at https://lumi.csc.fi)"
        echo "  2. The endpoint_url in [${SECTION}] matches your LUMI-O project endpoint"
        cat ./lumio-bucket-list 2>/dev/null || true
        rm -f ./lumio-bucket-list
        exit 1
    fi
else
    echo "NOTE: endpoint_url not found in [${SECTION}] of ~/.aws/credentials or ~/.aws/config"
    echo "      — skipping live connectivity check."
    echo "To enable the full curl test, add endpoint_url to one of:"
    echo "  ~/.aws/credentials  [${SECTION}]  endpoint_url = https://<project-number>.lumidata.eu"
    echo "  ~/.aws/config       [profile ${SECTION}]  endpoint_url = https://<project-number>.lumidata.eu"
    echo "  (find it at https://lumi.csc.fi → your project → Object Storage → Access keys)"
    echo ""
    echo "Credentials format OK — considering this a pass."
fi

echo ""
echo "SUCCESS: LUMI-O credentials check passed"
