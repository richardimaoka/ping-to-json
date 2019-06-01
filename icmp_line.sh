#!/bin/sh

# ----------------------------------------------------------------------------------------
# You pass a single ping icmp_seq line like below, as input stream
#   > 64 bytes from 10.116.4.5: icmp_seq=5 ttl=255 time=98.2 ms
# and this produecs JSON of it
# ----------------------------------------------------------------------------------------
ICMP_LINE=$(cat)

if [ -z "${ICMP_LINE}" ]; then
  >&2 echo 'ERROR: std input is empty'
  exit 1
elif [ "$(echo "${ICMP_LINE}" | wc -l)" -ne 1 ]; then
  >&2 echo 'ERROR: Multiple lines in std input:'
  >&2 echo "${ICMP_LINE}"
  exit 1
else
  FIRST_HALF=$(echo "${ICMP_LINE}" | awk  -F':' '{print $1}') # (e.g.) "64 bytes from 10.116.4.5" or "64 bytes from nrt20s09-in-f14.1e100.net (172.217.161.78)"
  SECOND_HALF=$(echo "${ICMP_LINE}" | awk -F':' '{print $2}') # (e.g.) " icmp_seq=1 ttl=57 time=8.77 ms"

  # part-by-part validation in FIRST_HALF
  FIRST_HALF_FIRST_PART=$(echo "${FIRST_HALF}"  | awk '{print $1}') # (e.g.) "64"
  FIRST_HALF_SECOND_PART=$(echo "${FIRST_HALF}" | awk '{print $2}') # "bytes"
  FIRST_HALF_THIRD_PART=$(echo "${FIRST_HALF}"  | awk '{print $3}') # "from"
  FIRST_HALF_FOURTH_PART=$(echo "${FIRST_HALF}" | awk '{print $4}') # (e.g.) "10.116.4.5" or "nrt20s09-in-f14.1e100.net"
  FIRST_HALF_FIFTH_PART=$(echo "${FIRST_HALF}"  | awk '{print $5}') # (e.g.) "" or "(172.217.161.78)"

  if [ -z "$(echo "${FIRST_HALF_FIRST_PART}" | awk '/^[0-9]+$/')" ] ; then
    >&2 echo "ERROR: '${FIRST_HALF_FIRST_PART}' are not digits"
    >&2 echo 
    exit 1
  elif [ "${FIRST_HALF_SECOND_PART}" != "bytes" ] ; then
    >&2 echo "ERROR: '${FIRST_HALF_SECOND_PART}' is not equal to 'bytes'"
    >&2 echo 
    exit 1
  elif [ "${FIRST_HALF_THIRD_PART}" != "from" ] ; then
    >&2 echo "ERROR: '${FIRST_HALF_THIRD_PART}' is not equal to 'from'"
    >&2 echo 
    exit 1
  elif [ -z "${FIRST_HALF_FOURTH_PART}" ] ; then
    >&2 echo "ERROR: empty host name or ip address"
    >&2 echo 
    exit 1
  elif [ -n "${FIRST_HALF_FIFTH_PART}" ] && [ -z "$(echo "${FIRST_HALF_FIFTH_PART}" | awk '/^\(([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\)$/')" ]; then # awk regex does not allow \d{1,3}
    >&2 echo "ERROR: '${FIRST_HALF_FIFTH_PART}' is not in the form of '(***.***.***.***)'"
    >&2 echo 
    exit 1
  fi

  # retrieve values from FIRST_HALF
  BYTES="${FIRST_HALF_FIRST_PART}"
  TARGET="${FIRST_HALF_FOURTH_PART}"
  if [ -z "${FIRST_HALF_FIFTH_PART}" ]; then
    TARGET_IP="${FIRST_HALF_FOURTH_PART}"
  else
    TARGET_IP="$(echo "${FIRST_HALF_FIFTH_PART}" | sed -e "s/(//" | sed -e "s/)//" )"
  fi

  # part-by-part validation in SECOND_HALF
  SECOND_HALF_FIRST_PART=$(echo "${SECOND_HALF}"  | awk '{print $1}') # (e.g.) "icmp_seq=1"
  SECOND_HALF_SECOND_PART=$(echo "${SECOND_HALF}" | awk '{print $2}') # (e.g.) "ttl=57"
  SECOND_HALF_THIRD_PART=$(echo "${SECOND_HALF}"  | awk '{print $3}') # (e.g.) "time=98.2"
  SECOND_HALF_FOURTH_PART=$(echo "${SECOND_HALF}"  | awk '{print $4}') # (e.g.) "ms"

  if [ -z "$(echo "${SECOND_HALF_FIRST_PART}" | awk '/^icmp_seq=[0-9]+$/')" ] ; then
    >&2 echo "ERROR: '${SECOND_HALF_FIRST_PART}' is not in the form of 'icmp_seq=*'"
    >&2 echo 
    exit 1
  elif [ -z "$(echo "${SECOND_HALF_SECOND_PART}" | awk '/^ttl=[0-9]+$/')" ] ; then
    >&2 echo "ERROR: '${SECOND_HALF_SECOND_PART}' is not in the form of 'ttl=*'"
    >&2 echo 
    exit 1
  elif [ -z "$(echo "${SECOND_HALF_THIRD_PART}" | awk '/^time=([0-9]*[.])?[0-9]+$/')" ] ; then
    >&2 echo "ERROR: '${SECOND_HALF_THIRD_PART}' is not in the form of 'time=*'"
    >&2 echo 
    exit 1
  fi

  # Validate and retrieve values from SECOND_HALF_XXX
  # (e.g.) "icmp_seq=1"
  ICMP_SEQ=$(echo "${SECOND_HALF_FIRST_PART}" | sed "s/icmp_seq=//" | awk '/^[0-9]+$/')
  if [ -z "${ICMP_SEQ}" ]; then 
    >&2 echo "ERROR: Cannot retrieve the icmp_seq value from '${SECOND_HALF_FIRST_PART}'"
    >&2 echo
    exit 1
  fi
  TTL=$(echo "${SECOND_HALF_SECOND_PART}" | sed "s/ttl=//" | awk '/^[0-9]+$/')
  if [ -z "${TTL}" ]; then 
    >&2 echo "ERROR: Cannot retrieve the ttl value from '${SECOND_HALF_SECOND_PART}'"
    >&2 echo
    exit 1
  fi
  TIME_VALUE=$(echo "${SECOND_HALF_THIRD_PART}" | sed "s/time=//" | awk '/^([0-9]*[.])?[0-9]+$/')
  if [ -z "${TIME_VALUE}" ]; then 
    >&2 echo "ERROR: Cannot retrieve the time value from '${SECOND_HALF_THIRD_PART}'"
    >&2 echo
    exit 1
  fi
  TIME_UNIT="${SECOND_HALF_FOURTH_PART}"
  case "$TIME_UNIT" in
    ms)
      TIME_UNIT="milliseconds"
      ;;
    s)
      TIME_UNIT="seconds"
      ;;
  esac

  echo "{"  
  echo "  \"bytes\": ${BYTES},"
  echo "  \"target\": \"${TARGET}\","
  echo "  \"target_ip\": \"${TARGET_IP}\","
  echo "  \"icmp_seq\": ${ICMP_SEQ},"
  echo "  \"ttl\": ${TTL},"
  echo "  \"time\": {"
  echo "    \"unit\": \"${TIME_UNIT}\","
  echo "    \"value\": ${TIME_VALUE}"
  echo "  }"  
  echo "}"  
fi
