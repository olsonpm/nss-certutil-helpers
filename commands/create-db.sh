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

__create_db_dir='./'


#------#
# Main #
#------#

create_db() {
  echo
  val=''

  # handle options
  while getopts ":hd:-:" opt; do
    case "${opt}" in
      -)
        case "${OPTARG}" in
          help)
            usage 1
            exit 0
          ;;
          directory)
            eval val=\$$OPTIND; OPTIND=$((OPTIND + 1))
            __create_db_dir="${val}"
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
      d)
        __create_db_dir="${OPTARG}"
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

  if file_exists "${__create_db_dir}/cert9.db" \
    || file_exists "${__create_db_dir}/key4.db" \
    || file_exists "${__create_db_dir}/pkcs11.txt"; then

    log_error "Please select a directory that doesn't have existing nss database files\n"
    usage 2
    exit 1
  fi

  if [ "${__create_db_dir}" != './' ]; then
    mkdir -p "${__create_db_dir}"
  fi

  certutil -N -d "sql:${__create_db_dir}" --empty-password

  printf "Done!\n\n"
}


#-------------#
# Helper Fxns #
#-------------#

usage() {
  print_usage 'create-db' "${1}"
}


#-----#
# Run #
#-----#

create_db "${@}"
