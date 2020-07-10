#!/usr/bin/env bash
#
# This library is designed to help manipulate illumina samplesheets.
# Ideally every implementations drafted here should be later implemented
# in the python project illumina-helper.
#
source logging.lib

ssheet__curlNbTries=3
ssheet__curlRetryDelay=1
ssheet__curlRetryMaxTimes=5

ssheet__withTags=false
ssheet__projectTag="Project_"
ssheet__sampleTag="Sample_"
ssheet__filename="samplesheet.csv"
ssheet__delimiter=","
ssheet__projectStartRegex="\(^\|${ssheet__delimiter}\)"
ssheet__projectEndRegex="\(${ssheet__delimiter}\|\$\)"

ssheet__sampleIdRegex="Sample.*ID"
ssheet__sampleNameRegex="Sample.*Name"
ssheet__projectNameRegex="Sample.*Project"
ssheet__dataHeaderRegex='\[Data\]'

# -----------
# Structure
# -----------
function ssheet__sampleTagStructed() {
  $ssheet__withTags && printf "${ssheet__sampleTag}" || printf ""
}  

function ssheet__projectTagStructed() {
  $ssheet__withTags && printf "${ssheet__projectTag}" || printf ""
}  

function ssheet__removeTag() {
  sed -e "s/^${1}//" \
   < /dev/stdin
}

function ssheet__removeProjectTag() {
   ssheet__removeTag "$(ssheet__projectTagStructed)" \
   < /dev/stdin
}
function ssheet__projectRegex() {
  printf "${ssheet__projectStartRegex}"
  ssheet__projectTagStructed
  printf "${1}${ssheet__projectEndRegex}"
}

function ssheet__noEmptyLine() {
  sed '/^$/d' < /dev/stdin
}

function ssheet__2unix() {
  tr '\r' '\n' < /dev/stdin
}

function ssheet__rmSpaces() {
  sed 's/[[:space:]]//g' < /dev/stdin
}

function ssheet__build() {
  ssheet__fetch "$1"     \
   | ssheet__2unix       \
   | ssheet__noEmptyLine \
   | ssheet__noSpaces
}

function ssheet__noSpaces() {
  local ssheet=$(cat /dev/stdin)
  ssheet__metadata    <<< "$ssheet"
  ssheet__data <<< "$ssheet" \
   | ssheet__rmSpaces
}

function ssheet__tagData() {
  local ssheet=$(cat /dev/stdin)
  ssheet__metadata    <<< "$ssheet"
  ssheet__dataHeader  <<< "$ssheet"
  ssheet__data        <<< "$ssheet" \
   | ssheet__addDataTags

}

function ssheet__addDataTags() {
  #
  # Takes sample sheet data and formats samples
  # Careful, the header should be included.
  #
  local ssheet="$(cat /dev/stdin)"
  colSampleId=$(ssheet__dataColumnIndex "$ssheet__sampleIdRegex" <<< "$ssheet")
  colSampleName=$(ssheet__dataColumnIndex "$ssheet__sampleNameRegex" <<< "$ssheet")
  colPrjName=$(ssheet__dataColumnIndex "$ssheet__projectNameRegex" <<< "$ssheet")
  awk -F"$ssheet__delimiter" \
    '{
        OFS=FS;
        $'"$colSampleId"'= "'"${ssheet__sampleTag}"'" $'"$colSampleId"'; 
        $'"$colPrjName"'= "'"${ssheet__projectTag}"'" $'"$colPrjName"'; 
        print $0 
      }'                     \
   < <(ssheet__dataSamples <<< "$ssheet")
}


function ssheet__projectFiltered() {
  #
  # Reads a sample sheet content and builds another one from it for the specified project.
  #
  local ssheet=$(cat /dev/stdin)
  local prj="${1:+$1}"
  ssheet__metadata   <<< "$ssheet"
  ssheet__dataHeader <<< "$ssheet"
  ssheet__data       <<< "$ssheet" \
   | ssheet__filterProject "$prj"
} 

function ssheet__filterProject() {
  #
  # Takes a samplesheet's data and filters the lines with the given project name.
  #
  local prj="${1:+$1}"
  grep -- $(ssheet__projectRegex "${prj}") \
   < /dev/stdin                        \
    || warnecho "Could not find project '$prj' in samplesheet."
}


# -----------------------
# Fetching Sample Sheet
# -----------------------
function ssheet__fetch() {
  #
  # Fetches the given sample sheet either as a remote or local file.
  #
  local ssheet="$1"
  if ssheet__isRemote "$ssheet"; then
    ssheet__download "$ssheet" \
     || errexit "Couldn't download sample sheet '$ssheet'."
  else
    ssheet__readLocal "$ssheet" \
     || errexit "Sample sheet '$ssheet' is not a local file."
  fi
}

function ssheet__isRemote() {
  #
  # Checks if given file is remote from IP or https.
  #
  local remote_regex="(^\b([0-9]{1,3}\.){3}[0-9]{1,3}\b)|(^https?://)"
  grep -qE "$remote_regex" <<< "$1" \
   && return 0 \
   || return 1
}

function ssheet__readLocal() {
  local ssheet="$1"
  [ -f "$ssheet" ] || return 1
  local ssheet="$ssheet"
  cat "$ssheet"
}

function ssheet__download() {
  local ssheet="$1"
  ssheet__downloadCmdExec "$ssheet"
}

function ssheet__downloadCmdExec() {
  eval "$(ssheet__downloadCmd $@)"
}

function ssheet__downloadCmd() {
  local ssheet="$1"
  cat << eol
  curl -f -s "$ssheet" \
   --retry $ssheet__curlNbTries \
   --retry-delay $ssheet__curlRetryDelay \
   --retry-max-time $ssheet__curlRetryMaxTimes
eol
}

# ---------------------------
# Sample Sheet Manipulation
# ---------------------------
function ssheet__headerLine() {
  #
  # Returns the line of the samplesheet's data header.
  #
  cat /dev/stdin \
   | grep -n "$ssheet__dataHeaderRegex" \
   | awk -F':' '{print $1}'
}

function ssheet__metadata() {
  #
  # Outputs the metadata from the given sample sheet file.
  #
  local ssheet="$(cat /dev/stdin)"
  head -n $(ssheet__headerLine <<< "$ssheet") \
   <<< "$ssheet"
}

function ssheet__data() {
  #
  # Outputs the data from the given sample sheet file. 
  #
  local ssheet="$(cat /dev/stdin)"
  tail -n +$(( $(ssheet__headerLine <<< "$ssheet") +1 )) \
    <<< "$ssheet" 
}

function ssheet__hasData() {
  if [ $(ssheet__dataSamples < /dev/stdin | wc -l) -ge 1 ]; then
    return 0
  else
    return 1
  fi
}

function ssheet__dataHeader() {
  #
  # Outputs the data header from the given sample sheet file. 
  #
  cat /dev/stdin  \
   | ssheet__data \
   | head -n 1
}

function ssheet__dataSamples() {
  #
  # Outputs the data samples from the given sample sheet file. 
  #
  cat /dev/stdin  \
   | ssheet__data \
   | tail -n +2
}

function ssheet__dataColumnIndex() {
  #
  # Gets a samplesheet and a column name.
  # Returns the index of the column name.
  #
  local colNamePattern="$1"
  cat /dev/stdin              \
   | csv.get-col-names        \
      -d "$ssheet__delimiter" \
      --output-delimiter '\n' \
      --count                 \
      --after-counter '\t'    \
   | grep "$colNamePattern"   \
   | awk -F'\t' '{print $1}'
}

function ssheet__projects() {
  #
  # Takes a sample sheet and returns all projects found in it.
  #
  local ssheet="$(cat /dev/stdin)"
  local colidx_prj=$(
    ssheet__data <<< "$ssheet"    \
     | ssheet__dataColumnIndex "$ssheet__projectNameRegex"
  )
  ssheet__dataSamples <<< "$ssheet" \
   | awk -F"$ssheet__delimiter"     \
       '{print $'"$colidx_prj"'}'   \
   | ssheet__removeProjectTag       \
   | sort                           \
   | uniq
}
