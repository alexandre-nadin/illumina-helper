#!/usr/bin/env sh

# -------------------
# Date-time library
# -------------------
function dt_std_datetime() {
  #
  # Prints the current date-time.
  #
  date +%y-%m-%d' '%H:%M:%S
}

function dt_run_reset_datetime() {
  #
  # (Re)Sets the script's starting date-time.
  #
  RUN_DATE_TIME=($(dt_std_datetime))
}

function dt_run_init_datetime() {
  #
  # Sets the script's starting date-time is not already done.
  #
  [ -z "${RUN_DATE_TIME:+x}" ] \
   && dt_run_reset_datetime
}

function dt_run_date() {
  #
  # Prints the script's starting date.
  #
  dt_run_init_datetime
  echo "${RUN_DATE_TIME[0]}"  
}

function dt_run_time() {
  #
  # Prints the script's starting time.
  #   
  dt_run_init_datetime
  echo "${RUN_DATE_TIME[1]}" 
}

function dt_run_datetime() {
  #
  # Prints the script's starting date-time
  #
  dt_run_init_datetime
  echo "${RUN_DATE_TIME[@]}"
}

function dt_run_datetime_file_format() {
  #
  # Prints the script's starting date-time for file name.
  #
  dt_run_init_datetime
  dt_file_format "$(dt_run_date)_$(dt_run_time)"
}

function dt_file_format() {
  #
  # Prints the standard date-time formatted for file names
  #
  local dt="$(dt_std_datetime)"
  [ ! -z "$1" ] && dt="$1"
  echo "$dt" \
   | sed -e 's| |_|g' \
         -e 's|:||g' \
         -e 's|-||g'
}

function dt_run_datetime_log_format() {
  #
  # Prints the script's starting date-time for logging.
  #
  dt_run_init_datetime
  echo "$(dt_run_date) $(dt_run_time)"
}

function dt_log_format() {
  #
  # Takes a date-time and formats it for file names
  # Takes standard date-time by default.
  #
  echo $(dt_std_datetime) 
}
