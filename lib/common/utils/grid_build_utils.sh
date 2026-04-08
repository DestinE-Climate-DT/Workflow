#!/bin/bash

################################################################################
# Grid Build Utility Functions
# Purpose: All grid building logic and utilities (no template-specific code)
# NOTE: Grid parameters (ocean grid name, resolution, component) must be
# defined in model config files (AQUA.GRID_OCE, CONFIGURATION.IFS.RESOL)
# NO workflow logic, NO filesystem access
################################################################################

#####################################################
# Check if a grid file already exists.
# Args: component_dir, gridname, dimension (2D|3D|"")
# Returns: 0 if found, 1 if not
#####################################################
function check_grid_exists() {
    local component_dir="$1"
    local gridname="$2"
    local dimension="${3:-}"

    case "${dimension}" in
    2D)
        # Look for 2D pattern: *_oce*.nc (but NOT *_level*.nc)
        for file in "${component_dir}"/*"${gridname}"*_oce*.nc; do
            [[ -f "${file}" && "${file}" != *"_level"* ]] && return 0
        done
        ;;
    3D)
        # Look for 3D pattern: *_level*.nc
        for file in "${component_dir}"/*"${gridname}"*_level*.nc; do
            [[ -f "${file}" ]] && return 0
        done
        ;;
    *)
        # Generic check
        for file in "${component_dir}"/*"${gridname}"*.nc; do
            [[ -f "${file}" ]] && return 0
        done
        ;;
    esac
    return 1
}

#####################################################
# Look up the grid filename from the YAML registry.
# Handles both inline paths (ICON 3D) and nested
# paths under vert_coord key (FESOM/NEMO 3D).
# Args: yaml_file, entry_name, [vert_coord]
# Returns: filename via stdout, 0 if found, 1 if not
#####################################################
function get_grid_filename_from_yaml() {
    local yaml_file="$1"
    local entry_name="$2"
    local vert_coord="${3:-}"

    [[ ! -f "${yaml_file}" ]] && return 1
    grep -q "^  ${entry_name}:" "${yaml_file}" 2>/dev/null || return 1

    # Extract only this entry's block (stop at the next top-level entry)
    local entry_block
    entry_block=$(awk "/^  ${entry_name}:/{found=1; print; next} found && /^  [a-zA-Z]/{exit} found{print}" "${yaml_file}")

    local path_value=""

    # If vert_coord given, try nested first: {vert_coord}: '...filename.nc'
    if [[ -n "${vert_coord}" ]]; then
        path_value=$(echo "${entry_block}" | sed -n "s/.*${vert_coord}: *['\"]\\(.*\\.nc\\)['\"].*/\\1/p" | head -1)
    fi

    # Fall back to inline path: path: '...filename.nc' (works for 2D and ICON 3D)
    if [[ -z "${path_value}" ]]; then
        path_value=$(echo "${entry_block}" | sed -n "s/.*path: *['\"]\\(.*\\.nc\\)['\"].*/\\1/p" | head -1)
    fi

    if [[ -n "${path_value}" ]]; then
        basename "${path_value}"
        return 0
    fi

    return 1
}

#####################################################
# Build a grid using the AQUA container.
#
# Runs AQUA grids build, then finds the output file
# by its known pattern (2d or 3d) and renames it to
# the registry naming convention. If the target file
# already exists, skips the rename.
#
# For registry-only grids (e.g. atmosphere HEALPix),
# pass write_yaml="true" so AQUA writes the registry
# entry itself (no physical file is created).
#
# Args: catalog, model_upper, expver, source,
#       gridname_lower, component_upper, original_upper,
#       version, outdir, loglevel, verify, fix, rebuild,
#       aqua_container, aqua_config, bindings,
#       [vert_coord], [write_yaml]
# Returns: 0 on success, 1 on failure
#####################################################
function build_grid_with_aqua() {
    local catalog="$1"
    local model_upper="$2"
    local expver="$3"
    local source="$4"
    local gridname_lower="$5"
    local component_upper="$6"
    local original_upper="$7"
    local version="$8"
    local outdir="$9"
    local loglevel="${10:-INFO}"
    local verify="${11:-true}"
    local fix="${12:-true}"
    local rebuild="${13:-false}"
    local aqua_container="${14}"
    local aqua_config="${15}"
    local bindings="${16}"
    local vert_coord="${17:-}"
    local write_yaml="${18:-false}"

    # Extract healpix zoom from source name (e.g., daily-hpz7-oce2d → hpz7)
    local hpz_zoom=""
    if [[ "${source}" =~ (hpz[0-9]+) ]]; then
        hpz_zoom="${BASH_REMATCH[1]}"
    else
        echo "ERROR: Cannot extract healpix zoom from source: ${source}"
        return 1
    fi

    # Determine target filename.
    # If the YAML registry already has this entry, use its filename
    # (respects model-specific conventions: ICON _level_full, FESOM/NEMO _level).
    # Otherwise fall back to our default convention.
    local yaml_file="${aqua_config}/grids/${gridname_lower}.yaml"
    local entry_name
    if [[ -n "${vert_coord}" ]]; then
        entry_name="${gridname_lower}-${original_upper}-${hpz_zoom}-nested-3d-v${version}"
    else
        entry_name="${gridname_lower}-${original_upper}-${hpz_zoom}-nested-v${version}"
    fi

    local target_name=""
    target_name=$(get_grid_filename_from_yaml "${yaml_file}" "${entry_name}" "${vert_coord}") || true

    if [[ -z "${target_name}" ]]; then
        local type_suffix="oce"
        if [[ -n "${vert_coord}" ]]; then
            # ICON uses _level_full convention, FESOM/NEMO use _level
            if [[ "${gridname_lower}" == "icon" ]]; then
                type_suffix="oce_${vert_coord}_full"
            else
                type_suffix="oce_${vert_coord}"
            fi
        fi
        target_name="${gridname_lower}-${original_upper}_${hpz_zoom}_nested_${type_suffix}_v${version}.nc"
    fi
    local target_path="${outdir}/${target_name}"

    # Skip if target already exists and rebuild not requested
    if [[ -f "${target_path}" ]] && [[ "${rebuild,,}" != "true" ]]; then
        echo "Grid file already exists: ${target_name} — skipping"
        return 0
    fi

    echo "Building grid: ${component_upper} ${original_upper} (${gridname_lower}, v${version})"
    echo "  Source: ${source}"
    echo "  Output: ${outdir}"

    # Build AQUA command
    local aqua_cmd="aqua grids build"
    aqua_cmd+=" --catalog ${catalog}"
    aqua_cmd+=" -m ${model_upper}"
    aqua_cmd+=" -e ${expver}"
    aqua_cmd+=" -s ${source}"
    aqua_cmd+=" --gridname ${gridname_lower}"
    aqua_cmd+=" --modelname ${component_upper}"
    aqua_cmd+=" --original ${original_upper}"
    aqua_cmd+=" --version ${version}"
    aqua_cmd+=" --outdir ${outdir}"
    aqua_cmd+=" --loglevel ${loglevel}"

    [[ "${write_yaml,,}" == "true" ]] && aqua_cmd+=" --yaml"
    [[ -n "${vert_coord}" ]] && aqua_cmd+=" --vert_coord ${vert_coord}"
    [[ "${verify,,}" == "true" ]] && aqua_cmd+=" --verify"
    [[ "${fix,,}" == "true" ]] && aqua_cmd+=" --fix"
    [[ "${rebuild,,}" == "true" ]] && aqua_cmd+=" --rebuild"

    echo "Running: ${aqua_cmd}"

    singularity exec \
        --cleanenv \
        --env PYTHONPATH=/opt/conda/lib/python3.10/site-packages \
        --env ESMFMKFILE=/opt/conda/lib/esmf.mk \
        --env PYTHONPATH=/app/AQUA \
        --env AQUA=/app/AQUA \
        --env AQUA_CONFIG="${aqua_config}" \
        --env CATALOG_NAME="${catalog}" \
        ${bindings} \
        --no-mount /etc/localtime \
        "${aqua_container}" \
        bash -c "aqua set ${catalog} && ${aqua_cmd}"

    if [ $? -ne 0 ]; then
        echo "ERROR: Grid build command failed"
        return 1
    fi

    echo "Grid build command completed successfully"

    # Find the file AQUA created.
    # AQUA outputs lowercase names: {grid}_{original}_{hpz}_nested_{2d|3d_vert}_v{N}.nc
    local original_lower
    original_lower=$(echo "${original_upper}" | tr '[:upper:]' '[:lower:]')
    local aqua_file=""

    if [[ -n "${vert_coord}" ]]; then
        # 3D: look for *_3d_* pattern
        for f in "${outdir}"/${gridname_lower}_${original_lower}_*_3d_*_v${version}.nc; do
            [[ -f "$f" ]] && aqua_file="$f" && break
        done
    else
        # 2D: look for *_2d_* pattern
        for f in "${outdir}"/${gridname_lower}_${original_lower}_*_2d_v${version}.nc; do
            [[ -f "$f" ]] && aqua_file="$f" && break
        done
    fi

    # If no file found, check for registry-only grids (HEALPix atmosphere)
    if [ -z "${aqua_file}" ]; then
        if [[ "${write_yaml,,}" == "true" ]]; then
            echo "No physical file created (registry-only grid)"
            return 0
        fi
        echo "ERROR: No grid file found after build"
        ls -la "${outdir}/" 2>/dev/null || true
        return 1
    fi

    # Rename to target
    echo "AQUA created: $(basename "${aqua_file}")"
    echo "Target name:  ${target_name}"

    if [ "${aqua_file}" != "${target_path}" ]; then
        mv "${aqua_file}" "${target_path}"
        echo "SUCCESS: Renamed to ${target_name}"
    else
        echo "File already has correct name"
    fi

    return 0
}

#####################################################
# Add a grid entry to the AQUA YAML registry.
# Writes to the model-specific YAML with {{ grids }}
# template paths (not the healpix.yaml that AQUA uses).
# Args: aqua_config, gridname_lower, component_upper,
#       original_upper, healpix, version, dimension,
#       [vert_coord]
# Returns: 0 on success, 1 on failure
#####################################################
function update_grid_registry() {
    local aqua_config="$1"
    local gridname_lower="$2"
    local component_upper="$3"
    local original_upper="$4"
    local healpix="$5"
    local version="$6"
    local dimension="$7"
    local vert_coord="${8:-}"

    local yaml_file="${aqua_config}/grids/${gridname_lower}.yaml"

    # Construct entry name and path following pre-defined conventions in fesom.yaml
    local entry_name
    local file_path
    if [ "${dimension}" = "2D" ]; then
        entry_name="${gridname_lower}-${original_upper}-${healpix}-nested-v${version}"
        file_path="{{ grids }}/${component_upper}/${gridname_lower}-${original_upper}_${healpix}_nested_oce_v${version}.nc"
    else
        entry_name="${gridname_lower}-${original_upper}-${healpix}-nested-3d-v${version}"
        # ICON uses _level_full convention, FESOM/NEMO use _level
        if [[ "${gridname_lower}" == "icon" ]]; then
            file_path="{{ grids }}/${component_upper}/${gridname_lower}-${original_upper}_${healpix}_nested_oce_${vert_coord}_full_v${version}.nc"
        else
            file_path="{{ grids }}/${component_upper}/${gridname_lower}-${original_upper}_${healpix}_nested_oce_${vert_coord}_v${version}.nc"
        fi
    fi

    echo "Updating grid registry: ${entry_name} in ${yaml_file}"

    # If entry already exists, skip — the upstream YAML is authoritative
    if grep -q "^  ${entry_name}:" "${yaml_file}" 2>/dev/null; then
        echo "Grid entry ${entry_name} already exists in ${yaml_file} — skipping"
        return 0
    fi

    if [ ! -f "${yaml_file}" ]; then
        echo "grids:" >"${yaml_file}"
    fi

    # Ensure trailing newline before appending
    [ -s "${yaml_file}" ] && [ "$(tail -c1 "${yaml_file}" | wc -l)" -eq 0 ] && echo "" >>"${yaml_file}"

    if [ "${dimension}" = "2D" ]; then
        cat >>"${yaml_file}" <<EOF
  ${entry_name}:
    cdo_options: "--force"
    space_coord: ["ncells"]
    path: '${file_path}'
EOF
    else
        cat >>"${yaml_file}" <<EOF
  ${entry_name}:
    cdo_options: "--force"
    path:
      ${vert_coord}: '${file_path}'
    space_coord: ["ncells"]
    vert_coord: ["${vert_coord}"]
EOF
    fi

    echo "Successfully added grid entry ${entry_name} to ${yaml_file}"
    return 0
}
