#!/bin/sh

# ----------------------------------------------------------------------------------------
# You pass the whole ping output as input stream, and this produces the JSON of it.
# You can do like this (e.g.):
#   ping -c 5 google.com | ping-script/ping_to_json.sh | jq
# ----------------------------------------------------------------------------------------

# cd to the current directory as it runs other shell scripts

icmp_line_handler() {

  ICMP_LINE=$1

  if [ -z "${ICMP_LINE}" ]; then
    echo >&2 'ERROR: std input is empty'
    exit 1
  elif [ "$(echo "${ICMP_LINE}" | wc -l)" -ne 1 ]; then
    echo >&2 'ERROR: Multiple lines in std input:'
    echo >&2 "${ICMP_LINE}"
    exit 1
  else
    FIRST_HALF=$(echo "${ICMP_LINE}" | awk -F':' '{print $1}')  # (e.g.) "64 bytes from 10.116.4.5" or "64 bytes from nrt20s09-in-f14.1e100.net (172.217.161.78)"
    SECOND_HALF=$(echo "${ICMP_LINE}" | awk -F':' '{print $2}') # (e.g.) " icmp_seq=1 ttl=57 time=8.77 ms"

    # part-by-part validation in FIRST_HALF
    FIRST_HALF_FIRST_PART=$(echo "${FIRST_HALF}" | awk '{print $1}')  # (e.g.) "64"
    FIRST_HALF_SECOND_PART=$(echo "${FIRST_HALF}" | awk '{print $2}') # "bytes"
    FIRST_HALF_THIRD_PART=$(echo "${FIRST_HALF}" | awk '{print $3}')  # "from"
    FIRST_HALF_FOURTH_PART=$(echo "${FIRST_HALF}" | awk '{print $4}') # (e.g.) "10.116.4.5" or "nrt20s09-in-f14.1e100.net"
    FIRST_HALF_FIFTH_PART=$(echo "${FIRST_HALF}" | awk '{print $5}')  # (e.g.) "" or "(172.217.161.78)"

    if [ -z "$(echo "${FIRST_HALF_FIRST_PART}" | awk '/^[0-9]+$/')" ]; then
      echo >&2 "ERROR: '${FIRST_HALF_FIRST_PART}' are not digits"
      echo >&2
      exit 1
    elif [ "${FIRST_HALF_SECOND_PART}" != "bytes" ]; then
      echo >&2 "ERROR: '${FIRST_HALF_SECOND_PART}' is not equal to 'bytes'"
      echo >&2
      exit 1
    elif [ "${FIRST_HALF_THIRD_PART}" != "from" ]; then
      echo >&2 "ERROR: '${FIRST_HALF_THIRD_PART}' is not equal to 'from'"
      echo >&2
      exit 1
    elif [ -z "${FIRST_HALF_FOURTH_PART}" ]; then
      echo >&2 "ERROR: empty host name or ip address"
      echo >&2
      exit 1
    elif [ -n "${FIRST_HALF_FIFTH_PART}" ] && [ -z "$(echo "${FIRST_HALF_FIFTH_PART}" | awk '/^\(([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\)$/')" ]; then # awk regex does not allow \d{1,3}
      echo >&2 "ERROR: '${FIRST_HALF_FIFTH_PART}' is not in the form of '(***.***.***.***)'"
      echo >&2
      exit 1
    fi

    # retrieve values from FIRST_HALF
    BYTES="${FIRST_HALF_FIRST_PART}"
    TARGET="${FIRST_HALF_FOURTH_PART}"
    if [ -z "${FIRST_HALF_FIFTH_PART}" ]; then
      TARGET_IP="${FIRST_HALF_FOURTH_PART}"
    else
      TARGET_IP="$(echo "${FIRST_HALF_FIFTH_PART}" | sed -e "s/(//" | sed -e "s/)//")"
    fi

    # part-by-part validation in SECOND_HALF
    SECOND_HALF_FIRST_PART=$(echo "${SECOND_HALF}" | awk '{print $1}')  # (e.g.) "icmp_seq=1"
    SECOND_HALF_SECOND_PART=$(echo "${SECOND_HALF}" | awk '{print $2}') # (e.g.) "ttl=57"
    SECOND_HALF_THIRD_PART=$(echo "${SECOND_HALF}" | awk '{print $3}')  # (e.g.) "time=98.2"
    SECOND_HALF_FOURTH_PART=$(echo "${SECOND_HALF}" | awk '{print $4}') # (e.g.) "ms"

    if [ -z "$(echo "${SECOND_HALF_FIRST_PART}" | awk '/^icmp_seq=[0-9]+$/')" ]; then
      echo >&2 "ERROR: '${SECOND_HALF_FIRST_PART}' is not in the form of 'icmp_seq=*'"
      echo >&2
      exit 1
    elif [ -z "$(echo "${SECOND_HALF_SECOND_PART}" | awk '/^ttl=[0-9]+$/')" ]; then
      echo >&2 "ERROR: '${SECOND_HALF_SECOND_PART}' is not in the form of 'ttl=*'"
      echo >&2
      exit 1
    elif [ -z "$(echo "${SECOND_HALF_THIRD_PART}" | awk '/^time=([0-9]*[.])?[0-9]+$/')" ]; then
      echo >&2 "ERROR: '${SECOND_HALF_THIRD_PART}' is not in the form of 'time=*'"
      echo >&2
      exit 1
    fi

    # Validate and retrieve values from SECOND_HALF_XXX
    # (e.g.) "icmp_seq=1"
    ICMP_SEQ=$(echo "${SECOND_HALF_FIRST_PART}" | sed "s/icmp_seq=//" | awk '/^[0-9]+$/')
    if [ -z "${ICMP_SEQ}" ]; then
      echo >&2 "ERROR: Cannot retrieve the icmp_seq value from '${SECOND_HALF_FIRST_PART}'"
      echo >&2
      exit 1
    fi
    TTL=$(echo "${SECOND_HALF_SECOND_PART}" | sed "s/ttl=//" | awk '/^[0-9]+$/')
    if [ -z "${TTL}" ]; then
      echo >&2 "ERROR: Cannot retrieve the ttl value from '${SECOND_HALF_SECOND_PART}'"
      echo >&2
      exit 1
    fi
    TIME_VALUE=$(echo "${SECOND_HALF_THIRD_PART}" | sed "s/time=//" | awk '/^([0-9]*[.])?[0-9]+$/')
    if [ -z "${TIME_VALUE}" ]; then
      echo >&2 "ERROR: Cannot retrieve the time value from '${SECOND_HALF_THIRD_PART}'"
      echo >&2
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
}

cd "$(dirname "$0")" || exit

while read -r line; do
  if echo "${line}" | grep "bytes from" | grep "icmp_seq=" | grep "ttl=" | grep -q "time="; then
    if [ -z "${ICMP_SEQUENCES}" ]; then
      # ICMP_SEQUENCES="$(echo "${line}" | ./icmp_line.sh)"
      ICMP_SEQUENCES=$(icmp_line_handler "${line}")
    else
      ICMP_SEQ=$(icmp_line_handler "${line}")
      ICMP_SEQUENCES="${ICMP_SEQUENCES}, ${ICMP_SEQ}"
      # ICMP_SEQUENCES="${ICMP_SEQUENCES}, $(echo "${line}" | ./icmp_line.sh)"
    fi
  elif echo "${line}" | grep -q "rtt min/avg/max/mdev"; then
    if [ -n "${RTT_STATISTICS_JSON}" ]; then
      echo >&2 "ERROR: There must be only one RTT statistics line, but '${line}' appeared as another one. Previous RTT statistics is:"
      echo >&2 "${RTT_STATISTICS_JSON}"
      exit 1
    else
      RTT_STATISTICS_JSON="$(echo "${line}" | ./rtt_statistics.sh)"
    fi
  elif echo "${line}" | grep "packets transmitted, " | grep "received, " | grep " packet loss, " | grep -q "time "; then
    if [ -n "${RTT_SUMMARY_JSON}" ]; then
      echo >&2 "ERROR: There must be only one RTT summary line, but '${line}' appeared as another one. Previous RTT summary is:"
      echo >&2 "${RTT_SUMMARY_JSON}"
      exit 1
    else
      RTT_SUMMARY_JSON="$(echo "${line}" | ./rtt_summary.sh)"
    fi
  fi
done </dev/stdin

if [ -z "${RTT_STATISTICS_JSON}" ]; then
  echo >&2 "ERROR: RTT statistics line is not found, which starts with rtt min/avg/max/mdev"
  exit 1
elif [ -z "${RTT_SUMMARY_JSON}" ]; then
  echo >&2 "ERROR: RTT summary line is not found, which is like '** packets transmitted, ** received, *% packet loss, time ****ms'"
  exit 1
fi

echo "{"
echo "  \"rtt_summary\": ${RTT_SUMMARY_JSON},"
echo "  \"rtt_statistics\": ${RTT_STATISTICS_JSON},"
echo "  \"icmp_sequences\": [${ICMP_SEQUENCES}]"
echo "}"
