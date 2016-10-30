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

__sign_csr_caNick=''
__sign_csr_csrFpath=''


#------#
# Main #
#------#

sign_csr() {
  val=''

  # handle options
  while getopts ":hn:f:-:" opt; do
    case "${opt}" in
      -)
        case "${OPTARG}" in
          help)
            usage 1
            exit 0
          ;;
          ca-nickname)
            eval val=\$$OPTIND; OPTIND=$((OPTIND + 1))
            __sign_csr_caNick="${val}"
          ;;
          csr-filepath)
            eval val=\$$OPTIND; OPTIND=$((OPTIND + 1))
            __sign_csr_csrFpath="${val}"
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
        __sign_csr_caNick="${OPTARG}"
      ;;
      f)
        __sign_csr_csrFpath="${OPTARG}"
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
  if [ "${__sign_csr_caNick}" = '' ]; then
    needsRequiredArgs="--ca-nickname ${needsRequiredArgs}"
  fi
  if [ "${__sign_csr_csrFpath}" = '' ]; then
    needsRequiredArgs="--csr-filepath ${needsRequiredArgs}"
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

  # no errors! werrrrrrrd

  caNick="${__sign_csr_caNick}"
  csrFpath="${__sign_csr_csrFpath}"

  certutil -C -d 'sql:.' -i "${csrFpath}" -c "${caNick}"
}


#-------------#
# Helper Fxns #
#-------------#

usage() {
  echo
  print_usage 'sign-csr' "${1}"
}


#-----#
# Run #
#-----#

sign_csr "${@}"
