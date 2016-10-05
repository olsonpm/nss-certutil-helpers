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

__export_cert_nick=''
__export_cert_fpath=''
__export_cert_exportAll=1
__export_cert_certOnly=0
__export_cert_chainOnly=0
__export_cert_keyOnly=0
__export_cert_format='pem'
__export_cert_tmp=''
__export_cert_contentsId=''


#------#
# Main #
#------#

export_cert() {
  echo
  val=''
  # handle options
  while getopts ":hr:n:f:cak-:" opt; do
    case "${opt}" in
      -)
        case "${OPTARG}" in
          help)
            usage 1
            exit 0
          ;;
          nickname)
            eval val=\$$OPTIND; OPTIND=$((OPTIND + 1))
            __export_cert_nick="${val}"
          ;;
          filepath)
            eval val=\$$OPTIND; OPTIND=$((OPTIND + 1))
            __export_cert_fpath="${val}"
          ;;
          cert-only)
            validateOnlys
            __export_cert_certOnly=1
          ;;
          chain-only)
            validateOnlys
            __export_cert_chainOnly=1
          ;;
          key-only)
            validateOnlys
            __export_cert_keyOnly=1
          ;;
          format)
            eval val=\$$OPTIND; OPTIND=$((OPTIND + 1))
            validateAndSetFormat "${val}"
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
        __export_cert_nick="${OPTARG}"
      ;;
      f)
        __export_cert_fpath="${OPTARG}"
      ;;
      c)
        validateOnlys
        __export_cert_certOnly=1
      ;;
      a)
        validateOnlys
        __export_cert_chainOnly=1
      ;;
      k)
        validateOnlys
        __export_cert_keyOnly=1
      ;;
      r)
        validateAndSetFormat "${OPTARG}"
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

  if [ "${__export_cert_nick}" = '' ]; then
    log_error "--nickname is required\n"
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

  if [ "${__export_cert_format}" = 'p12' ] \
    && [ "${__export_cert_exportAll}" != "1" ]; then

    log_error "when --format is set to 'p12', use of the *-other flags is invalid"
    usage 2
    exit 1
  fi

  # The following only needs to be in the validation block since the file name
  #   depends on it
  flags=''
  __export_cert_contentsId=''
  if [ "${__export_cert_exportAll}" = "1" ]; then
    flags="-nodes"
    __export_cert_contentsId='all'
    umask 277
  elif [ "${__export_cert_certOnly}" = "1" ]; then
    flags="-nokeys -clcerts"
    __export_cert_contentsId='crt'
  elif [ "${__export_cert_chainOnly}" = "1" ]; then
    flags="-nokeys"
    __export_cert_contentsId='chain'
  else # if [ "${__export_cert_keyOnly}" = "1" ]; then
    flags="-nodes -nocerts"
    __export_cert_contentsId='key'
    umask 277
  fi

  if [ "${__export_cert_fpath}" = '' ]; then
    __export_cert_fpath="${__export_cert_nick}.${__export_cert_contentsId}.pem"
  fi

  __export_cert_tmp="${__export_cert_fpath%.*}.p12"

  if file_exists "${__export_cert_tmp}"; then
    log_error "Please remove the conflicting file '${__export_cert_fpath}' and try again\n" \
      "(export-cert needs this as a temporary file)"
    usage 2
    exit 1
  elif [ "${__export_cert_format}" = 'pem' ] \
    && file_exists "${__export_cert_fpath}"; then

    log_error "Please remove the conflicting file '${__export_cert_fpath}' and try again\n"
    usage 2
    exit 1
  fi

  # no errors! woo woo

  # shellcheck disable=2086
  pk12util -o "${__export_cert_tmp}" -d . -n "${__export_cert_nick}" -W '' >/dev/null 2>&1

  if [ $? -ne 0 ]; then
    rm -f "${__export_cert_tmp}"
    cmd="pk12util -o ${__export_cert_tmp} -d . -n '${__export_cert_nick}' -W ''"
    printf "Error occurred while running the following command %b\n\n" "${cmd}" >&2

    pk12util -o "${__export_cert_tmp}" -d . -n "${__export_cert_nick}" -W ''
    exit 1
  fi

  # the job is done if the format is 'p12'
  if [ "${__export_cert_format}" = 'p12' ]; then
    printf "Done!\n\n"
    exit 0
  fi

  # shellcheck disable=2086
  openssl pkcs12 -in "${__export_cert_tmp}" -out "${__export_cert_fpath}" ${flags} -password 'pass:' >/dev/null 2>&1

  if [ $? -ne 0 ]; then
    rm -f "${__export_cert_tmp}"
    cmd="openssl pkcs12 -in ${__export_cert_tmp} -out ${__export_cert_fpath} ${flags} -password 'pass:'"
    printf "Error occurred while running the following command %b\n\n" "${cmd}" >&2

    # shellcheck disable=2086
    openssl pkcs12 -in "${__export_cert_tmp}" -out "${__export_cert_fpath}" ${flags} -password 'pass:'
    exit 1
  fi

  rm -f "${__export_cert_tmp}"
  printf "Done!\n\n"
}


#-------------#
# Helper Fxns #
#-------------#

usage() {
  print_usage 'export-cert' "${1}"
}

validateOnlys() {
  if [ "${__export_cert_certOnly}" = "1" ] \
    || [ "${__export_cert_chainOnly}" = "1" ] \
    || [ "${__export_cert_keyOnly}" = "1" ]; then

    log_error "Multiple *-only flags cannot be passed"
    usage 2
    exit 1
  fi

  # a convenience hack which depends on the behavior of validateOnly's being
  #   called only when an *-only is being set.
  __export_cert_exportAll=0
}

validateAndSetFormat() {
  __export_cert_format="${1}"
  if [ "${__export_cert_format}" != 'pem' ] \
    && [ "${__export_cert_format}" != 'p12' ]; then

    log_error "--format must either be 'pem' or 'p12'"
    usage 2
    exit 1
  fi
}


#-----#
# Run #
#-----#

export_cert "${@}"
