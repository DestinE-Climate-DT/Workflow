# Tests for common/utils/remote_setup_utils.sh

## setup

setup() {
	bats_load_library bats-support
	bats_load_library bats-assert

	# get the containing directory of this file
	# use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
	# as those will point to the bats executable's location or the preprocessed file respectively
	DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
	# source file under test
	source "${DIR}/../../../../lib/common/utils/remote_setup_utils.sh"

}

@test "by default post_compilation_ifs-nemo returns true" {
    run post_compilation_ifs-nemo
    assert_success "true"
}

@test "by default post_compilation_icon returns true" {
    run post_compilation_icon
    assert_success "true"
}

@test "by default post_compilation_nemo returns true" {
    run post_compilation_nemo
    assert_success "true"
}

@test generate_nemo_env_file {
	ARCH_NAME="test_arch"
	mkdir -p "arch"
	NEMO_NETCDF_FORTRAN_PATH="fortran_path"
	NEMO_XIOS_PATH="xios_path"
	NEMO_CPP="nemo_cpp"
	NEMO_CC="nemo_cc"
	NEMO_FC="nemo_fc"
	NEMO_FCFLAGS="nemo_fcflags"
	FCFLAGS="fc_flags"
	FC="fc"
	NEMO_LDFLAGS="nemo_ldflags"
	NEMO_FPPFLAGS="nemo_fppflags"

	run generate_nemo_env_file
	cat > expected_output.txt <<EOF
%NCDF_INC            -Ifortran_path/include
%NCDF_LIB            -Lfortran_path/lib -L/lib -L/lib -lhdf5 -lhdf5_hl -lnetcdf -lnetcdff
%XIOS_INC            -Ixios_path/inc
%XIOS_LIB            -Lxios_path/lib -lxios -lstdc++
%CPP                 nemo_cpp
%CC                  nemo_cc
%FC                  nemo_fc
%FCFLAGS             nemo_fcflags
%FFLAGS              %FCFLAGS
%LD                  %FC
%LDFLAGS             nemo_ldflags
%FPPFLAGS            nemo_fppflags
%AR                  ar
%ARFLAGS             rs
%MK                  gmake
%USER_INC            %NCDF_INC %XIOS_INC
%USER_LIB            %NCDF_LIB %XIOS_LIB
EOF

	diff arch/arch-$ARCH_NAME.fcm expected_output.txt
	assert_success

	rm -rf "arch"
	rm expected_output.txt
}

@test "get_arch_compilation_flags returns the compilation flags in CPU case" {
	PU="cpu"
	ARCH_CPU="cpu/default"
	ARCH_GPU="gpu/default"
	ADDITIONAL_COMPILATION_FLAGS_CPU="--cpu-flag"
	ADDITIONAL_COMPILATION_FLAGS_GPU="--gpu-flag"
	get_arch_compilation_flags $PU $ARCH_CPU $ARCH_GPU $ADDITIONAL_COMPILATION_FLAGS_CPU $ADDITIONAL_COMPILATION_FLAGS_GPU
	assert_equal "${add_flags}" "${ADDITIONAL_COMPILATION_FLAGS_CPU}"
	assert_equal "${arch}" "${ARCH_CPU}"
}

@test "get_arch_compilation_flags returns the compilation flags in GPU case" {
	PU="gpu"
	ARCH_CPU="cpu/default"
	ARCH_GPU="gpu/default"
	ADDITIONAL_COMPILATION_FLAGS_CPU="--cpu-flag"
	ADDITIONAL_COMPILATION_FLAGS_GPU="--gpu-flag"
	get_arch_compilation_flags $PU $ARCH_CPU $ARCH_GPU $ADDITIONAL_COMPILATION_FLAGS_CPU $ADDITIONAL_COMPILATION_FLAGS_GPU
	assert_equal "${add_flags}" "${ADDITIONAL_COMPILATION_FLAGS_GPU}"
	assert_equal "${arch}" "${ARCH_GPU}"
}

## install_aqua

# Stand-in for `singularity exec`: drops the container flags and runs the inner
# script locally with the environment the real call would inject.
#
# `env -i` mirrors --cleanenv, so the inner shell sees only what was passed with
# --env, plus a PATH to reach the stubs. That is also what keeps this runnable
# under kcov: kcov traces bash through PS4/BASH_ENV, which reference BASH_SOURCE,
# and the inner script's `set -u` aborts on it in a `bash -c` shell.
singularity() {
	local envs=() script=""
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--env)
			envs+=("$2")
			shift 2
			;;
		-c)
			script="$2"
			shift 2
			;;
		*)
			shift
			;;
		esac
	done
	env -i PATH="${PATH}" "${envs[@]}" bash -c "${script}"
}

# Stubs for the two commands the inner script calls. Only catgen has a side
# effect: it writes the entry under the exp key it was configured with, which is
# the experiment name and never the expver. python3 just records its arguments,
# so the assertions can tell which entry install_aqua asked it to patch --
# update_aqua_config.py itself is covered by the Python tests.
write_command_stubs() {
	cat >"${STUB_BIN}/aqua" <<-'STUB'
		#!/bin/bash
		[ "$1" = "catgen" ] || exit 0
		touch "${HPCROOTDIR}/catgen_called.flag"
		ENTRY_DIR="${HPCROOTDIR}/catalog/catalogs/${CATALOG_NAME}/catalog/${MODEL_AND_RES}"
		mkdir -p "${ENTRY_DIR}"
		echo "sources: {}" >"${ENTRY_DIR}/${EXPERIMENT_NAME}.yaml"
	STUB

	cat >"${STUB_BIN}/python3" <<-'STUB'
		#!/bin/bash
		echo "$@" >>"${HPCROOTDIR}/python3_calls.log"
	STUB

	chmod +x "${STUB_BIN}/aqua" "${STUB_BIN}/python3"
}

# An operational-style run: the expver is pinned to 0001 while the catalog entry
# still carries the experiment name.
setup_install_aqua() {
	export HPCROOTDIR="${BATS_TEST_TMPDIR}/hpcroot"
	export STUB_BIN="${BATS_TEST_TMPDIR}/bin"
	mkdir -p "${HPCROOTDIR}" "${STUB_BIN}"
	PATH="${STUB_BIN}:${PATH}"

	write_command_stubs

	export AQUA="/app/AQUA"
	export AQUA_CONTAINER="${BATS_TEST_TMPDIR}/aqua.sif"
	export AQUA_REGENCAT="False"
	export AQUA_START_DATE="19900101"
	export CATALOG_NAME="climatedt-gen2"
	export DATA_PORTFOLIO="full"
	export EXPID="a000"
	export EXPVER="0001"
	export HPCARCH_short="MN5"
	export MODEL_NAME_UPPER="IFS-NEMO"
	export PROJDEST="proj"
	export SIM_START_DATE="19900101"

	ENTRY_DIR="${HPCROOTDIR}/catalog/catalogs/${CATALOG_NAME}/catalog/IFS-NEMO-5km"
}

# install_aqua arguments, with the realizations and experiment name last.
run_install_aqua() {
	install_aqua "${BATS_TEST_TMPDIR}/.aqua" "False" "" "ifs-nemo" "production" "" \
		"5km" "$1" "$2"
}

@test "install_aqua patches the entry catgen wrote, not one named after the expver" {
	setup_install_aqua

	run_install_aqua "6 7" "a000"

	[ -f "${ENTRY_DIR}/a000.yaml" ]
	run cat "${HPCROOTDIR}/python3_calls.log"
	assert_output --partial "update-realizations"
	assert_output --partial "--catalog_file ${ENTRY_DIR}/a000.yaml"
	assert_output --partial "--realizations 6 7"
}

@test "install_aqua leaves an existing entry alone when REGENERATE_CATALOGS is false" {
	setup_install_aqua

	mkdir -p "${ENTRY_DIR}"
	echo "sources: {}" >"${ENTRY_DIR}/a000.yaml"

	run_install_aqua "6 7" "a000"

	[ ! -f "${HPCROOTDIR}/catgen_called.flag" ]
}
