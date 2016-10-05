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

__create_cert_cn=''
__create_cert_nick=''
__create_cert_signedBy=''


#------#
# Main #
#------#

create_db() {
  echo
  val=''

  # handle options
  while getopts ":hc:n:s:-:" opt; do
    case "${opt}" in
      -)
        case "${OPTARG}" in
          help)
            usage 1
            exit 0
          ;;
          common-name)
            eval val=\$$OPTIND; OPTIND=$((OPTIND + 1))
            __create_cert_cn="${val}"
          ;;
          nickname)
            eval val=\$$OPTIND; OPTIND=$((OPTIND + 1))
            __create_cert_nick="${val}"
          ;;
          signed-by)
            eval val=\$$OPTIND; OPTIND=$((OPTIND + 1))
            __create_cert_signedBy="${val}"
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
      c)
        __create_cert_cn="${OPTARG}"
      ;;
      n)
        __create_cert_nick="${OPTARG}"
      ;;
      s)
        __create_cert_signedBy="${OPTARG}"
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

  needsRequiredArgs='';
  if [ "${__create_cert_cn}" = '' ]; then
    needsRequiredArgs="--common-name ${needsRequiredArgs}"
  fi
  if [ "${__create_cert_nick}" = '' ]; then
    needsRequiredArgs="--nickname ${needsRequiredArgs}"
  fi
  if [ "${__create_cert_signedBy}" = '' ]; then
    needsRequiredArgs="--signed-by ${needsRequiredArgs}"
  fi
  if [ "${needsRequiredArgs}" != '' ]; then
    log_error "The following arguments are missing: ${needsRequiredArgs}\n"
    usage 2
    exit 1
  fi

  if ! file_exists "./cert9.db" \
    || ! file_exists "./key4.db" \
    || ! file_exists "./pkcs11.txt"; then

    log_error "This command requires you to be in a directory with an NSS database\n"
    usage 2
    exit 1
  fi

  # no errors! we good fam

  trust=''
  selfsigned=''
  if [ "${__create_cert_signedBy}" = "self" ]; then
    trust='C,C,C'
    selfsigned='-x'
  else
    trust=',,'
  fi

  cn="${__create_cert_cn}"
  nick="${__create_cert_nick}"

  certutil -S -n "${nick}" -t "${trust}" "${selfsigned}" -d . -s "CN=${cn}"

  printf "Done!\n\n"
}


#-------------#
# Helper Fxns #
#-------------#

usage() {
  print_usage 'create-cert' "${1}"
}


#-----#
# Run #
#-----#

create_db "${@}"
