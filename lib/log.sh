#!/usr/bin/env sh


# shellcheck disable=2034
LOG_SRC=1

#---------#
# Imports #
#---------#

import constants


#------------------#
# Script Variables #
#------------------#

__log_res=


#------#
# Main #
#------#

log_warn () {
  __log_validate_message "${1}"
  msg="${__log_res}"

  printf "Warning: %b\n" "${msg}" >&2
}

log_error () {
  __log_validate_message "${1}"
  msg="${__log_res}"

  printf "Error: %b\n" "${msg}" >&2
}

log_fatal () {
  __log_validate_message "${1}"
  msg="${__log_res}"

  __log_validate_errno "${2}"
  errno="${__log_res}"

  printf "Error: %b\n\n" "${msg}" >&2
  printf "Please report a github issue so I can help you and others:\n" >&2
  printf "https://github.com/olsonpm/nss-certutil-helpers/issues/new\n\n" >&2
  exit "${errno}"
}


#-------------#
# Helper Fxns #
#-------------#

__log_validate_message () {
  if [ -z "${1+x}" ] || [ "${1}" = "" ]; then
    printf "Error: 'log_fatal' was called without a message argument.\n" >&2
    exit 1
  fi

  __log_res="${1}"
}

__log_validate_errno () {
  errno=1
  if [ "${1}" -eq "${1}" ] 2>/dev/null && [ ! "${1}" = "0" ]; then
    errno="${1}"
    if [ "${1}" -gt 255 ] || [ "${1}" -lt 1 ]; then
      printf "Warning: 'log_fatal' was called with an errno" >&1
      printf " greater than 255 or less than 1.  This may invoke an unexpected exit code.\n" >&1
    fi
    elif [ ! "${1}" = "" ]; then
    printf "Error: 'log_fatal' was called with an invalid errno: '%b'.\n" "${1}" >&2
    exit 1
  fi

  __log_res="${errno}"
}
