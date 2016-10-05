#! /usr/bin/env sh

# shellcheck disable=2034
PRINT_USAGE_SRC=1


#---------#
# Imports #
#---------#

import "log"


#------#
# Main #
#------#

print_usage () {
  if [ -z "${1+x}" ] || [ -z "${2+x}" ]; then
    log_fatal "'print_usage' must be given two arguments." 3
  fi

  file=$1
  out=$2

  cat "${ROOT_DIR}/usage/${file}.txt" >&"${out}"
  echo
}
