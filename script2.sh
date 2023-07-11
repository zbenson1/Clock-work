#!/bin/bash

INDEX="/eos/cms/store/group/dpg_trigger/comm_trigger/L1Trigger/www/DQMDC/RateMon/index.php"
FIRST_RUN_FLAG=".first_run"

# Checks if the code has been executed before
if [ -f "$FIRST_RUN_FLAG" ]; then
    echo "Welcome back!"
else
    echo "-Make sure you have your own CERN website in order to view plots!"
    echo "-If you're unsure, check at the following website:"
    echo "  https://webservices-portal.web.cern.ch/my-sites"
    echo "-If you do not, create your WebEOS site here:"
    echo "  https://webservices-portal.web.cern.ch/webeos"

# Create the flag file to indicate that the code has been executed once
    touch "$FIRST_RUN_FLAG"
fi

echo "Please enter your selected test runs or fills (separated by spaces or commas): "
read -r input_runs

# Function to validate fill numbers (4-digit)
validate_fills() {
  local fills=("$@")
  for fill in "${fills[@]}"; do
    if [[ ! $fill =~ ^[0-9]{4}$ ]]; then
      echo "Invalid fill number: $fill. Fill numbers must be four digits long."
      exit 1
    fi
  done
}

# Function to validate run numbers (6-digit)
validate_runs() {
  local runs=("$@")
  for run in "${runs[@]}"; do
    if [[ ! $run =~ ^[0-9]{6}$ ]]; then
      echo "Invalid run number: $run. Run numbers must be six digits long."
      exit 1
    fi
  done
}

# Function to remove duplicate entries.
remove_duplicates() {
    local input_runs="$1"
    local unique_runs=($(echo "${input_runs}" | tr -s ' ' '\n' | sort -u | tr '\n' ' '))
    echo "${unique_runs[*]}"
}

# Converts commas to spaces.
input_runs="${input_runs//,/ }"

# Remove duplicate entries.
unique_runs=$(remove_duplicates "$input_runs")

# Check whether the input is for fill-based or run-based entries
IFS=', ' read -r -a runs_array <<< "$unique_runs"
IFS=' ' read -r -a fills_array <<< "$unique_runs"

is_fill_entries=false
is_run_entries=false

# Validate the input
for run in "${runs_array[@]}"; do
  if [[ ! $run =~ ^[0-9]{6}$ ]]; then
    if [[ $run =~ ^[0-9]{4}$ ]]; then
      is_fill_entries=true
    else
      echo "Invalid input: $run. Please enter either six-digit run numbers or four-digit fill numbers."
      exit 1
    fi
  else
    is_run_entries=true
  fi
done

if "$is_fill_entries" && "$is_run_entries"; then
  echo "Invalid input: Please do not mix fill numbers and run numbers."
  exit 1
fi

if "$is_fill_entries"; then
  validate_fills "${fills_array[@]}"
else
  validate_runs "${runs_array[@]}"
fi

# Sorts the runs or fills in the array in ascending order.
if "$is_run_entries"; then
  sorted_runs_array=($(printf '%s\n' "${runs_array[@]}" | sort -n))
  run_dir_string="runs_${sorted_runs_array[0]}_to_${sorted_runs_array[-1]}"
else
  sorted_runs_array=($(printf '%s\n' "${fills_array[@]}" | sort -n))
  run_dir_string="fills_${sorted_runs_array[0]}_to_${sorted_runs_array[-1]}"
fi

# Stores all runs or fills separated by a space into a string and names file.
run_list_string="${sorted_runs_array[*]}"

# Checks if user has rate_plots already made, if not then it makes that directory.
if [ ! -d "rate_plots" ]; then
    mkdir rate_plots
fi

# Runs the python code to generate the plots.

if "$is_fill_entries"; then
  validate_fills "${fills_array[@]}"
else
  validate_runs "${runs_array[@]}"
fi

if "$is_run_entries"; then
    eval "python3 plotTriggerRates.py --triggerList=TriggerLists/monitorlist_L1T_certification_AWB.list --saveDirectory=rate_plots/${run_dir_string} ${run_list_string}"
else
     eval "python3 plotTriggerRates.py --useFills --triggerList=TriggerLists/monitorlist_L1T_certification_AWB.list --saveDirectory=rate_plots/${run_dir_string} ${run_list_string}"
fi

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to run plotTriggerRates.py for ${run_list_string}!"
    exit 1
fi

echo "Finished running plotTriggerRates.py!"

# Copies the index.php file to the rate_plots directory and sub-directories
echo "Now copying index.php file."

cp "$INDEX" rate_plots/
cp "$INDEX" rate_plots/${run_dir_string}/
cp "$INDEX" rate_plots/${run_dir_string}/png/

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to copy index.php file!"
    exit 1
fi

# Checks if user has CERN website and RateMon folder in EOS
if [ ! -d "/eos/user/${USER:0:1}/${USER}/www/" ]; then
    echo "ERROR: finish making your website!"
fi

if [ ! -d "/eos/user/${USER:0:1}/${USER}/www/L1T/RateMon/" ]; then
    echo "Preparing /eos/user/${USER:0:1}/${USER}/www/L1T/RateMon/ directory."
    mkdir -p "/eos/user/${USER:0:1}/${USER}/www/L1T/RateMon/"
fi

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create /eos/user/${USER:0:1}/${USER}/www/L1T/RateMon/!"
    exit 1
fi

# Copying .png files to web area
echo "Copying to /eos/user/${USER:0:1}/${USER}/www/L1T/RateMon/${run_dir_string}"

eval "cp -r rate_plots/${run_dir_string} '/eos/user/${USER:0:1}/${USER}/www/L1T/RateMon/'"
