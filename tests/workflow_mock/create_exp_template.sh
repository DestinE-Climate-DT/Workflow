#!/bin/bash

POSITIONAL_ARGS=()
MISSING_FLAGS=()
# Set the default value for the branch type flag
BRANCH_TYPE=""

# Set the values for the flags
while [[ $# -gt 0 ]]; do
    case $1 in
        --description)
            DESCRIPTION="$2"
            shift # past argument
            shift # past value
            ;;
        --hpc)
            HPC="$2"
            shift # past argument
            shift # past value
            ;;
        --git_as_conf)
            GIT_AS_CONF="$2"
            shift # past argument
            shift # past value
            ;;
        --git_repo)
            GIT_REPO="$2"
            shift # past argument
            shift # past value
            ;;
        --git_branch)
            GIT_BRANCH="$2"
            shift # past argument
            shift # past value
            ;;
        --template_path)
            WF_TEMPLATE_PATH="$2"
            shift # past argument
            shift # past value
            ;;
        --exps_home_dir)
            EXPS_HOME_DIR="$2"
            shift # past argument
            shift # past value
            ;;
        --branch_type)
            BRANCH_TYPE="$2"
            shift # past argument
            shift # past value
            ;;
        -*|--*)
            echo "Unknown option $1"
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1") # save positional arg
            shift # past argument
            ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

# Check if all flags are not empty except minimal configuration
if [[ -z $DESCRIPTION ]]; then
    MISSING_FLAGS+=("description")
fi

if [[ -z $HPC ]]; then
    MISSING_FLAGS+=("hpc")
fi

if [[ -z $GIT_AS_CONF ]]; then
    MISSING_FLAGS+=("git_as_conf")
fi

if [[ -z $GIT_REPO ]]; then
    MISSING_FLAGS+=("git_repo")
fi

if [[ -z $GIT_BRANCH ]]; then
    MISSING_FLAGS+=("git_branch")
fi

if [[ -z $WF_TEMPLATE_PATH ]]; then
    MISSING_FLAGS+=("template_path")
fi

if [[ -z $EXPS_HOME_DIR ]]; then
    MISSING_FLAGS+=("exps_home_dir")
fi

if [[ -z $BRANCH_TYPE ]]; then
    MISSING_FLAGS+=("branch_type")
fi

if [[ ${#MISSING_FLAGS[@]} -gt 0 ]]; then
    echo "Missing flags: ${MISSING_FLAGS[*]}"
    exit 1
fi

# Print all passed values
echo "Passed values:"
echo "Description: $DESCRIPTION"
echo "HPC: $HPC"
echo "Git as conf: $GIT_AS_CONF"
echo "Git repo: $GIT_REPO"
echo "Git branch: $GIT_BRANCH"
echo "Template path: $WF_TEMPLATE_PATH"
echo "Experiments home directory: $EXPS_HOME_DIR"


# Store the stdout and stderr to variables
output=$(autosubmit expid \
    --description "$DESCRIPTION" \
    --HPC "$HPC" \
    --git_as_conf "$GIT_AS_CONF" \
    --git_repo "$GIT_REPO" \
    --git_branch "$GIT_BRANCH" \
    --minimal_configuration 2>&1)

# Check if there was an error
if [[ $? -ne 0 ]]; then
    echo "Error: $output"
    exit 1
fi

# Process the output
echo "Output: $output"


# Extract the value from the output using regex
if [[ $output =~ Experiment\ ([a-zA-Z0-9]+)\ created ]]; then
    expid="${BASH_REMATCH[1]}"
    echo "ExpID: $expid"
else
    echo "Error: Failed to extract expid from output"
    exit 1
fi
exp_main_path="${EXPS_HOME_DIR}/${expid}/conf/main.yml"
exp_minimal_path="${EXPS_HOME_DIR}/${expid}/conf/minimal.yml"

cp "${WF_TEMPLATE_PATH}" "${exp_main_path}"

# Change a value in the exp_minimal_path
sed -i "s/PROJECT_SUBMODULES: ''/PROJECT_SUBMODULES: false/g" "$exp_minimal_path"

autosubmit create "$expid" -np
# check exit code
if [[ $? -ne 0 ]]; then
    echo "Error occurred while creating the experiment"
    exit 1
fi

autosubmit inspect "$expid" --quick -f
if [[ $? -ne 0 ]]; then
    echo "Error occurred while inspecting the experiment"
    exit 1
fi

current_date=$(date +"%Y-%m-%dT%H:%M:%S%z")
line="$expid,$current_date"
output_dir="output"
if [ ! -d "$output_dir" ]; then
    mkdir $output_dir
fi

output_file_name="created_experiments_${GIT_BRANCH}_${BRANCH_TYPE}.csv"

# replace / with _ in the output_file_name
output_file_name="${output_file_name//\//_}"
output_file_name="${output_dir}/${output_file_name}"

echo "Adding line to $output_file_name: $line"
echo "$line" >> $output_file_name

echo "Done"
