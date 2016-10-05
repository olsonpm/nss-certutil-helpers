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

__create_csr_cn=''


#------#
# Main #
#------#

create_csr() {
  val=''

  # handle options
  while getopts ":hc:-:" opt; do
    case "${opt}" in
      -)
        case "${OPTARG}" in
          help)
            usage 1
            exit 0
          ;;
          common-name)
            eval val=\$$OPTIND; OPTIND=$((OPTIND + 1))
            __create_csr_cn="${val}"
          ;;
          *)
            log_error "\nUnknown option '--${OPTARG}'\n"
            usage 2
            exit 1
          ;;
        esac
      ;;
      h)
        usage 1
        exit 0
      ;;
      c)
        __create_csr_cn="${OPTARG}"
      ;;
      \?)
        log_error "\nInvalid option given: -${OPTARG}\n"
        usage 2
        exit 1
      ;;
      *)
        log_error "\nInvalid option given: -${OPTARG}\n"
        usage 2
        exit 1
      ;;
    esac
  done

  shift $((OPTIND - 1))
  if [ "$#" -gt 0 ]; then
    log_error "\nThis command doesn't have unnamed arguments\n"
    usage 2
    exit 1
  fi

  if [ "${__create_csr_cn}" = '' ]; then
    log_error "\n--common-name is required\n"
    usage 2
    exit 1
  fi

  if ! file_exists "./cert9.db" \
    || ! file_exists "./key4.db" \
    || ! file_exists "./pkcs11.txt"; then

    log_error "\nThis command requires you to be in a directory with an NSS database\n"
    usage 2
    exit 1
  fi

  # no errors! omg shoes

  certutil -d . -R -s "CN=${__create_csr_cn}"
}


#-------------#
# Helper Fxns #
#-------------#

usage() {
  echo
  print_usage 'create-csr' "${1}"
}


#-----#
# Run #
#-----#

create_csr "${@}"
