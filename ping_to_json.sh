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

rtt_statistics_handler() {
  RTT_LINE=$1

  if [ -z "${RTT_LINE}" ]; then
    echo >&2 'ERROR: std input for the RTT statistics line is empty'
    exit 1
  elif ! echo "${RTT_LINE}" | grep -q "rtt min/avg/max/mdev"; then
    echo >&2 'ERROR: std input for the RTT statistics line does not start with "rtt min/avg/max/mdev":'
    echo >&2 ">${RTT_LINE}"
    exit 1
  elif [ "$(echo "${RTT_LINE}" | wc -l)" -ne 1 ]; then
    echo >&2 'ERROR: Multiple lines in std input for the RTT statistics line:'
    echo >&2 ">${RTT_LINE}"
    exit 1
  else
    # Parse the line (e.g.) "rtt min/avg/max/mdev = 97.749/98.197/98.285/0.380 ms"

    # part-by-part validation
    FIRST_PART=$(echo "${RTT_LINE}" | awk '{print $1}')  # "rtt"
    SECOND_PART=$(echo "${RTT_LINE}" | awk '{print $2}') # "min/avg/max/mdev"
    THIRD_PART=$(echo "${RTT_LINE}" | awk '{print $3}')  # "="
    FOURTH_PART=$(echo "${RTT_LINE}" | awk '{print $4}') # (e.g.) "97.749/98.197/98.285/0.380"
    FIFTH_PART=$(echo "${RTT_LINE}" | awk '{print $5}')  # (e.g.) "ms"

    if [ "${FIRST_PART}" != "rtt" ]; then
      echo >&2 "ERROR: '${FIRST_PART}' is not equal to 'rtt', in the below RTT line:"
      echo >&2 ">${RTT_LINE}"
      exit 1
    elif [ "${SECOND_PART}" != "min/avg/max/mdev" ]; then
      echo >&2 "ERROR: '${SECOND_PART}' is not equal to 'min/avg/max/mdev', in the below RTT line:"
      echo >&2 ">${RTT_LINE}"
      exit 1
    elif [ "${THIRD_PART}" != "=" ]; then
      echo >&2 "ERROR: '${THIRD_PART}' is not equal to '=', in the below RTT line:"
      echo >&2 ">${RTT_LINE}"
      exit 1
    # FOURTH_PART to be validated later
    elif [ -n "$(echo "${FIFTH_PART}" | awk "/[1-9]/")" ]; then
      echo >&2 "ERROR: '${FIFTH_PART}' should not include any digit, in the below RTT line:"
      echo >&2 ">${RTT_LINE}"
      exit 1
    fi

    # Validate and retrieve values from FOURTH_PART
    # (e.g.) "97.749/98.197/98.285/0.380"
    RTT_MIN=$(echo "${FOURTH_PART}" | awk -F'/' '{print $1}' | awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
    if [ -z "${RTT_MIN}" ]; then
      echo >&2 "ERROR: Cannot retrieve the first number from '${FOURTH_PART}', in the below RTT line:"
      echo >&2 ">${RTT_LINE}"
      exit 1
    fi
    # (e.g.) "97.749/98.197/98.285/0.380"
    RTT_AVG=$(echo "$FOURTH_PART" | awk -F'/' '{print $2}' | awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
    if [ -z "${RTT_AVG}" ]; then
      echo >&2 "ERROR: Cannot retrieve the second number from '${FOURTH_PART}', in the below RTT line:"
      echo >&2 ">${RTT_LINE}"
      exit 1
    fi
    # (e.g.) "97.749/98.197/98.285/0.380"
    RTT_MAX=$(echo "$FOURTH_PART" | awk -F'/' '{print $3}' | awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
    if [ -z "${RTT_MAX}" ]; then
      echo >&2 "ERROR: Cannot retrieve the third number from '${FOURTH_PART}', in the below RTT line:"
      echo >&2 ">${RTT_LINE}"
      exit 1
    fi
    # (e.g.) "97.749/98.197/98.285/0.380"
    RTT_MDEV=$(echo "$FOURTH_PART" | awk -F'/' '{print $4}' | awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
    if [ -z "${RTT_MDEV}" ]; then
      echo >&2 "ERROR: Cannot retrieve the fourth number from '${FOURTH_PART}', in the below RTT line:"
      echo >&2 ">${RTT_LINE}"
      exit 1
    fi

    RTT_UNIT=$(echo "${RTT_LINE}" | awk '{print $5}')
    case "$RTT_UNIT" in
    ms)
      RTT_UNIT="milliseconds"
      ;;
    s)
      RTT_UNIT="seconds"
      ;;
    esac

    # JSON like below
    # {
    #   "min":  { "value": 97.749, "unit": "milliseconds" },
    #   "avg":  { "value": 98.197, "unit": "milliseconds" },
    #   "max":  { "value": 98.285, "unit": "milliseconds" },
    #   "mdev": { "value": 0.380,  "unit":"milliseconds" }
    # }
    echo "{"
    echo "  \"min\":  { \"value\": \"${RTT_MIN}\",  \"unit\": \"${RTT_UNIT}\" },"
    echo "  \"avg\":  { \"value\": \"${RTT_AVG}\",  \"unit\": \"${RTT_UNIT}\" },"
    echo "  \"max\":  { \"value\": \"${RTT_MAX}\",  \"unit\": \"${RTT_UNIT}\" },"
    echo "  \"mdev\": { \"value\": \"${RTT_MDEV}\", \"unit\": \"${RTT_UNIT}\" }"
    echo "}"
  fi

}

rtt_summary_handler() {
  SUMMARY_LINE=$1

  if [ -z "${SUMMARY_LINE}" ]; then
    echo >&2 'ERROR: std input for the RTT summary line is empty'
    exit 1
  elif ! echo "${SUMMARY_LINE}" | grep "packets transmitted, " | grep "received, " | grep " packet loss, " | grep -q "time "; then
    echo >&2 'ERROR: std input for the RTT summary line is not in the form of "** packets transmitted, ** received, *% packet loss, time ****ms"'
    echo >&2 ">${SUMMARY_LINE}"
    exit 1
  elif [ "$(echo "${SUMMARY_LINE}" | wc -l)" -ne 1 ]; then
    echo >&2 'ERROR: Multiple lines in std input for the RTT summary line:'
    echo >&2 ">${SUMMARY_LINE}"
    exit 1
  else
    # Parse the line (e.g.) "30 packets transmitted, 30 received, 0% packet loss, time 29034ms"

    # part-by-part validation
    FIRST_PART=$(echo "${SUMMARY_LINE}" | awk -F',' '{print $1}')  # (e.g.) "30 packets transmitted"
    SECOND_PART=$(echo "${SUMMARY_LINE}" | awk -F',' '{print $2}') # (e.g.) " 30 received"
    THIRD_PART=$(echo "${SUMMARY_LINE}" | awk -F',' '{print $3}')  # (e.g.) " 0% packet loss"
    FOURTH_PART=$(echo "${SUMMARY_LINE}" | awk -F',' '{print $4}') # (e.g.) " time 29034ms"

    if [ -z "$(echo "${FIRST_PART}" | awk "/^[0-9]+\spackets\stransmitted$/")" ]; then
      echo >&2 "ERROR: '${FIRST_PART}' is not in the form of '** packets transmitted', from the below summary line:"
      echo >&2 ">${SUMMARY_LINE}"
      exit 1
    elif [ -z "$(echo "${SECOND_PART}" | awk "/^\s[0-9]+\sreceived$/")" ]; then
      echo >&2 "ERROR: '${SECOND_PART}', is not in the form of ' ** received', from the below summary line:"
      echo >&2 ">${SUMMARY_LINE}"
      exit 1
    elif [ -z "$(echo "${THIRD_PART}" | awk "/^\s[0-9]+"%"\spacket\sloss$/")" ]; then
      echo >&2 "ERROR: '${THIRD_PART}', is not in the form of ' **% packet loss', from the below summary line:"
      echo >&2 ">${SUMMARY_LINE}"
      exit 1
    elif [ -z "$(echo "${FOURTH_PART}" | awk "/^\stime\s[0-9]+[a-z]{1,2}$/")" ]; then
      echo >&2 "ERROR: '${FOURTH_PART}', is not in the form of ' time **ms', from the below summary line:"
      echo >&2 ">${SUMMARY_LINE}"
      exit 1
    fi

    # 1. Parse the "30 packets transmitted" part of the SUMMARY_LINE
    # (e.g.) "30 packets transmitted"
    PACKETS_TRANSMITTED=$(echo "${FIRST_PART}" | awk '{print $1}' | awk '/^[0-9]+$/')
    if [ -z "${PACKETS_TRANSMITTED}" ]; then
      echo >&2 "ERROR: Cannot retrieve the packets transmitted value from '${FIRST_PART}', in the below summary line:"
      echo >&2 ">${SUMMARY_LINE}"
      exit 1
    fi
    # (e.g.) " 30 received"
    PACKETS_RECEIVED=$(echo "${SECOND_PART}" | awk '{print $1}' | awk '/^[0-9]+$/')
    if [ -z "${PACKETS_RECEIVED}" ]; then
      echo >&2 "ERROR: Cannot retrieve the packets received value from '${SECOND_PART}', in the below summary line:"
      echo >&2 ">${SUMMARY_LINE}"
      exit 1
    fi
    # (e.g.) " 0% packet loss"
    PACKET_LOSS_PERCENTAGE=$(echo "${THIRD_PART}" | awk '{print $1}' | sed 's/%//')
    if [ -z "${PACKET_LOSS_PERCENTAGE}" ]; then
      echo >&2 "ERROR: Cannot retrieve the packet loss percentage from '${THIRD_PART}', in the below summary line:"
      echo >&2 ">${SUMMARY_LINE}"
      exit 1
    fi
    # (e.g.)"time 29034ms"
    TIME_VALUE=$(echo "${FOURTH_PART}" | awk '{print $2}' | grep -o '^[0-9]*')
    if [ -z "${PACKETS_TRANSMITTED}" ]; then
      echo >&2 "ERROR: Cannot retrieve the time value from '${FOURTH_PART}', in the below summary line:"
      echo >&2 ">${SUMMARY_LINE}"
      exit 1
    fi
    TIME_UNIT=$(echo "${FOURTH_PART}" | awk '{print $2}' | sed 's/^[0-9]*//')
    if [ -z "${PACKETS_TRANSMITTED}" ]; then
      echo >&2 "ERROR: Cannot retrieve the time unit from '${FOURTH_PART}', in the below summary line:"
      echo >&2 ">${SUMMARY_LINE}"
      exit 1
    fi
    case "$TIME_UNIT" in
    ms)
      TIME_UNIT="milliseconds"
      ;;
    s)
      TIME_UNIT="seconds"
      ;;
    esac

    # JSON like below in a single line
    # {
    #   "packets_transmitted": 30,
    #   "packets_received": 30,
    #   "packet_loss_percentage": 0,
    #   "time": {
    #     "unit": "milliseconds",
    #     "value": 29034
    #   }
    # }
    echo "{"
    echo "  \"packets_transmitted\": ${PACKETS_TRANSMITTED},"
    echo "  \"packets_received\": ${PACKETS_RECEIVED},"
    echo "  \"packet_loss_percentage\": ${PACKET_LOSS_PERCENTAGE},"
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
      # RTT_STATISTICS_JSON="$(echo "${line}" | ./rtt_statistics.sh)"
      RTT_STATISTICS_JSON=$(rtt_statistics_handler "${line}")

    fi
  elif echo "${line}" | grep "packets transmitted, " | grep "received, " | grep " packet loss, " | grep -q "time "; then
    if [ -n "${RTT_SUMMARY_JSON}" ]; then
      echo >&2 "ERROR: There must be only one RTT summary line, but '${line}' appeared as another one. Previous RTT summary is:"
      echo >&2 "${RTT_SUMMARY_JSON}"
      exit 1
    else
      # RTT_SUMMARY_JSON="$(echo "${line}" | ./rtt_summary.sh)"
      RTT_SUMMARY_JSON=$(rtt_summary_handler "${line}")

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
