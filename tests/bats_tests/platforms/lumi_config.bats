# Tests for LUMI/config.sh

## setup

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    # source file under test
    source "${DIR}/../../../lib/LUMI/config.sh"
}

function grib_set(){
	local args="$@"
	echo "grib_set $args" >> "$GRIB_SET_CALLS_FILE"
	touch test.grib.tmp
}

@test "change_metadata sets multiple fields correctly" {

	GRIB_SET_CALLS_FILE=grib_set_calls.txt
	touch GRIB_SET_CALLS_FILE
	TEST_GRIB_FILE=test.grib
	touch $TEST_GRIB_FILE

	run change_metadata "experimentVerionNumber=0001,stepRange=12" "$TEST_GRIB_FILE"

    assert_success
        if ! grep -q -- "-s experimentVerionNumber=0001" "$GRIB_SET_CALLS_FILE"; then
        echo "Missing: -s experimentVerionNumber=0001 in $GRIB_SET_CALLS_FILE"
        exit 1
    fi

    if ! grep -q -- "-s stepRange=12" "$GRIB_SET_CALLS_FILE"; then
        echo "Missing: -s stepRange=12 in $GRIB_SET_CALLS_FILE"
        exit 1
    fi

	rm -f "$GRIB_SET_CALLS_FILE"
	rm -f "$TEST_GRIB_FILE"
}
