#!/bin/bash

INDEX="/eos/cms/store/group/dpg_trigger/comm_trigger/L1Trigger/www/DQMDC/RateMon/index.php"

# Checks if all runs entered are six digits long. If a non-six digit run is detected, the script will stop running and exit.

validate_runs() {
  local runs=("$@")
  for run in "${runs[@]}"; do
    if [[ ! $run =~ ^[0-9]{6}$ ]]; then
      echo "Invalid run number: $run. Run numbers must be six digits long."
      exit 1
    fi
  done
}

# Function to remove duplicate run entries.

remove_duplicates() {
    local input_runs="$1"
    local unique_runs=($(echo "${input_runs}" | tr -s ' ' '\n' | sort -u | tr '\n' ' '))
    echo "${unique_runs[*]}"
}

echo "-Make sure you have your own CERN website in order to view plots!"
echo "-If you're unsure, check at the following website:
      https://webservices-portal.web.cern.ch/my-sites"

echo "-If you do not, create your WebEOS site here:
       https://webservices-portal.web.cern.ch/webeos"

echo "Please enter your selected test runs (separated by spaces or commas): "
read -r input_runs

# Converts commas to spaces.

input_runs="${input_runs//,/, }"

# Remove duplicate run entries.

unique_runs=$(remove_duplicates "$input_runs")

# Converts user input to an array.

IFS=', ' read -r -a runs_array <<< "$input_runs"

# Validate runs to ensure they are six digits long.

validate_runs "${runs_array[@]}"

# Sorts the runs in the array in ascending order.

sorted_runs_array=($(printf '%s\n' "${runs_array[@]}" | sort -n))

# Stores all runs separated by a space into a string and names file.

run_list_string="${sorted_runs_array[*]}"
run_dir_string="runs_${sorted_runs_array[0]}_to_${sorted_runs_array[-1]}"

# Checks if user has rate_plots already made, if not then it makes that directory.

if [ ! -d "rate_plots" ]; then
    mkdir rate_plots
fi

# Runs the python code to generate the plots.

eval "python3 plotTriggerRates.py --triggerList=TriggerLists/monitorlist_COLLISIONS.list --saveDirectory=rate_plots/${run_dir_string} ${run_list_string}"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to run plotTriggerRates.py for runs ${run_list_string}!"
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

# Checks if user has CERN website and RateMon folder in eos

if [ ! -d "/eos/user/${USER:0:1}/${USER}/www/" ]; then
    echo "ERROR: finish making your website!"
fi

if [ ! -d "/eos/user/${USER:0:1}/${USER}/www/L1T/RateMon/" ]; then
    echo "Preparing /eos/user/${USER:0:1}/${USER}/www/L1T/RateMon/ directory."
    mkdir -p /eos/user/${USER:0:1}/${USER}/www/L1T/RateMon/
fi

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create /eos/user/${USER:0:1}/${USER}/www/L1T/RateMon/!"
    exit 1
fi

# Copying .png files to web area

echo "Copying to /eos/user/${USER:0:1}/${USER}/www/L1T/RateMon/${run_dir_string}"

eval "cp -r rate_plots/${run_dir_string} /eos/user/${USER:0:1}/${USER}/www/L1T/RateMon/."
