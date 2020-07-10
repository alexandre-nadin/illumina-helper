#!/usr/bin/env sh

# #############################################################################
# Simple way to use the library
# ============================================================================= 
#
# At any point in the script, we need to set the variable _log_log_file using
# the function log_set_log_file "FILE_PATH"
# 
# Then using the following main functions:
# $ verbecho "msg" 
# # Prints "msg" to STDERR only if the variable VERBOSE is set.
# 
# $ infecho "msg"  
# # Prints "msg" in STDERR only if the variable VERBOSE is set. 
# # Writes "msg" in /log/dir/log_name.log only if _log_log_file is 
#   declared and folder exists.
# 
# $ errecho "msg" 
# # Prints "msg" in STDERR. 
# # Writes "msg" in /log/dir/log_name.err only if _log_log_file is 
#   declared and folder exists.
# 
# $ errexit "msg"  
# # Prints "msg" in STDERR. 
# # Writes "msg" in /log/dir/log_name.log only if _log_log_file is 
#   declared and folder exists. 
# # Exits with status 1
#
#
# #############################################################################

source datetime.sh

LOG_INFO="INFO"
LOG_ERROR="ERROR"
LOG_WARNING="WARNING"
_log_log_file=${_log_log_file:-}  # Should be set with 'log_set_log_file' function.
LOG_LOG_EXT=".log"
LOG_ERR_EXT=".err"

# --------------------
# Wrappers of `echo`
# --------------------
function verbecho() {
  #   
  # Echoes input in stderr if in verbose mode.
  #
  [ -z "${VERBOSE:+x}" ] && return 0
  echo -e "$@" >&2
} && export -f verbecho

function infecho() {
  #
  # Calls verbecho because we don't want to display messages of type INFO 
  # by default, unless verbosity  VERBOSE is set.
  #
  verbecho "$@"
  log_write_info "$@"
} && export -f infecho

function warnecho() {
  echo -e "WARNING: $@" >&2
  log_write_warning "$@"
}

function debugecho() {
  #
  # Echoes debugging input in stderr if in DEBUG set.
  # Sets the verbosity on.
  # Resets the verbosity if was off before.
  #
  [ -z "${DEBUG:+x}" ] && return 0
  [ -z "${VERBOSE:+x}" ] \
   || local _was_verbose=true
  VERBOSE=true
  verbecho "DEBUG - $@" 
  [ -z "${_was_verbose:+x}" ] \
   && unset VERBOSE 
} && export -f debugecho

function errecho() {
  #   
  # Echoes input to stderr with error message.
  #
  echo -e "ERROR: $@" >&2
  log_write_error "$@"
} && export -f errecho

function errexit() {
  #   
  # errechoes the input and exits with error.
  #
  errecho "$@"
  exit 1
} && export -f errexit


# -----------------
# Logging library
# -----------------
function log_set_log_file() {
  #
  # Sets the log file. Checks the directory.
  #
  log_is_valid_log "$1" \
   && export _log_log_file="$1" \
   || return 1
  infecho "Starting logging."
}

function log_is_valid_log() {
  #
  # Takes a file path and checks that:
  #  - it is defined
  #  - it's directory exists
  #
  local _log_file=$(readlink -f "$1" 2> /dev/null)
  [ -z "${_log_file:+x}" ] && errecho  "Provide a valide path for the log file (given '$1')." && return 1 || true
  local _dirname=$(dirname "$_log_file")
  [ ! -d "$_dirname" ] && errecho "${FUNCNAME} - Dirname '$_dirname' does not exist." && return 1 || true
}

function log_can_write_log() {
  #
  # Tells if a log can be written by checking if :
  #  - _log_log_file is defined
  #  - _log_log_file's dirname is a directory
  #
  [ ! -z "${_log_log_file:+x}" ] \
   || return 1
  
  [ -d $(dirname "$_log_log_file") ] \
   || return 1
}

function log_write() {
  #
  # Writes message in a log file if it is possible.
  #
  log_can_write_log || return 0
  ## Writes output
  local log_type="$1" && shift
  local log_file="$1" && shift
  echo -e "[$(dt_log_format)][$log_type][$BASHPID] $@" \
   >> "$log_file" \
   || echo "cannot write to $log_file" >&2
}

function log_write_info() {
  #
  # Writes informative message in a log file.
  #
  log_write "$LOG_INFO" "${_log_log_file}${LOG_LOG_EXT}" "$@"
}

function log_write_warning() {
  #
  # Writes warning message in a log file.
  #
  log_write "$LOG_WARNING" "${_log_log_file}${LOG_LOG_EXT}" "$@"
}

function log_write_error() {
  #
  # Writes error message in a log file.
  #
  log_write "$LOG_ERROR" "${_log_log_file}${LOG_ERR_EXT}" "$@"
}
