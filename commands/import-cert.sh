#!/usr/bin/env sh


#---------#
# Imports #
#---------#

# shellcheck source=/dev/null
. "${ROOT_DIR}/lib/import.sh"
import log
import file-exists
import print-usage


#------------------#
# Script Variables #
#------------------#

__import_cert_fpath=''
__import_cert_nick=''
__import_cert_isRoot=0


#------#
# Main #
#------#

import_cert() {
  echo
  val=''
  # handle options
  while getopts ":hf:n:r-:" opt; do
    case "${opt}" in
      -)
        case "${OPTARG}" in
          help)
            usage 1
            exit 0
          ;;
          nickname)
            eval val=\$"${OPTIND}"; OPTIND=$((OPTIND + 1))
            __import_cert_nick="${val}"
          ;;
          filepath)
            eval val=\$"${OPTIND}"; OPTIND=$((OPTIND + 1))
            __import_cert_fpath="${val}"
          ;;
          is-root)
            __import_cert_isRoot=1
          ;;
          *)
            log_error "Unknown option '--${OPTARG}'\n"
            usage 2
            exit 1
          ;;
        esac
      ;;
      h)
        usage 1
        exit 0
      ;;
      n)
        __import_cert_nick="${OPTARG}"
      ;;
      f)
        __import_cert_fpath="${OPTARG}"
      ;;
      r)
        __import_cert_isRoot=1
      ;;
      \?)
        log_error "Invalid option given: -${OPTARG}\n"
        usage 2
        exit 1
      ;;
      *)
        log_error "Invalid option given: -${OPTARG}\n"
        usage 2
        exit 1
      ;;
    esac
  done

  shift $((OPTIND - 1))
  if [ "$#" -gt 0 ]; then
    log_error "This command doesn't have unnamed arguments\n"
    usage 2
    exit 1
  fi

  needsRequiredArgs=''
  if [ "${__import_cert_fpath}" = '' ]; then
    needsRequiredArgs="--filepath ${needsRequiredArgs}"
  fi
  if [ "${__import_cert_nick}" = '' ]; then
    needsRequiredArgs="--nickname ${needsRequiredArgs}"
  fi
  if [ "${needsRequiredArgs}" != '' ]; then
    log_error "The following arguments are missing: ${needsRequiredArgs}\n"
    usage 2
    exit 1
  fi

  # first group is the new files
  # second is for the old files (older certutil versions)
  if ! ( \
      ( file_exists "./cert9.db" \
      && file_exists "./key4.db" \
      && file_exists "./pkcs11.txt" \
      ) \
    || \
      ( file_exists "./cert8.db" \
      && file_exists "./key3.db" \
      && file_exists "secmod.db" \
      ) \
    ); then

    log_error "This command requires you to be in a directory with an NSS database\n"
    usage 2
    exit 1
  fi

  # no errors! aww yeea

  trust=',,'
  if [ "${__import_cert_isRoot}" = "1" ]; then
    trust='C,C,C'
  fi
  nick="${__import_cert_nick}"
  fpath="${__import_cert_fpath}"
  certutil -A -n "${nick}" -t "${trust}" -i "${fpath}" -d .

  printf "Done!\n\n"
}


#-------------#
# Helper Fxns #
#-------------#

usage() {
  print_usage 'import-cert' "${1}"
}


#-----#
# Run #
#-----#

import_cert "${@}"
