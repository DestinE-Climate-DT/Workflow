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
