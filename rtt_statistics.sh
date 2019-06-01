#!/bin/sh

# ----------------------------------------------------------------------------------------
# You pass a single ping RTT statistics line like below, as input stream
#   >rtt min/avg/max/mdev = 97.749/98.197/98.285/0.380 ms
# and this produecs JSON of it
# ----------------------------------------------------------------------------------------
RTT_LINE=$(cat)

if [ -z "${RTT_LINE}" ]; then
  >&2 echo 'ERROR: std input for the RTT statistics line is empty'
  exit 1
elif ! echo "${RTT_LINE}" | grep -q "rtt min/avg/max/mdev" ; then
  >&2 echo 'ERROR: std input for the RTT statistics line does not start with "rtt min/avg/max/mdev":'
  >&2 echo ">${RTT_LINE}"
  exit 1
elif [ "$(echo "${RTT_LINE}" | wc -l)" -ne 1 ]; then
  >&2 echo 'ERROR: Multiple lines in std input for the RTT statistics line:'
  >&2 echo ">${RTT_LINE}"
  exit 1
else
  # Parse the line (e.g.) "rtt min/avg/max/mdev = 97.749/98.197/98.285/0.380 ms"

  # part-by-part validation
  FIRST_PART=$(echo "${RTT_LINE}"  | awk '{print $1}') # "rtt"
  SECOND_PART=$(echo "${RTT_LINE}" | awk '{print $2}') # "min/avg/max/mdev"
  THIRD_PART=$(echo "${RTT_LINE}"  | awk '{print $3}') # "="
  FOURTH_PART=$(echo "${RTT_LINE}" | awk '{print $4}') # (e.g.) "97.749/98.197/98.285/0.380"
  FIFTH_PART=$(echo "${RTT_LINE}"  | awk '{print $5}') # (e.g.) "ms"

  if [ "${FIRST_PART}" != "rtt" ] ; then
    >&2 echo "ERROR: '${FIRST_PART}' is not equal to 'rtt', in the below RTT line:"
    >&2 echo ">${RTT_LINE}"
    exit 1
  elif [ "${SECOND_PART}" != "min/avg/max/mdev" ] ; then
    >&2 echo "ERROR: '${SECOND_PART}' is not equal to 'min/avg/max/mdev', in the below RTT line:"
    >&2 echo ">${RTT_LINE}"
    exit 1
  elif [ "${THIRD_PART}" != "=" ] ; then
    >&2 echo "ERROR: '${THIRD_PART}' is not equal to '=', in the below RTT line:"
    >&2 echo ">${RTT_LINE}"
    exit 1
  # FOURTH_PART to be validated later
  elif [ -n "$(echo "${FIFTH_PART}" | awk "/[1-9]/")" ]; then
    >&2 echo "ERROR: '${FIFTH_PART}' should not include any digit, in the below RTT line:"
    >&2 echo ">${RTT_LINE}"
    exit 1
  fi

  # Validate and retrieve values from FOURTH_PART
  # (e.g.) "97.749/98.197/98.285/0.380"
  RTT_MIN=$(echo "${FOURTH_PART}" | awk -F'/' '{print $1}'| awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
  if [ -z "${RTT_MIN}" ]; then 
    >&2 echo "ERROR: Cannot retrieve the first number from '${FOURTH_PART}', in the below RTT line:"
    >&2 echo ">${RTT_LINE}"
    exit 1
  fi
  # (e.g.) "97.749/98.197/98.285/0.380"
  RTT_AVG=$(echo "$FOURTH_PART" | awk -F'/' '{print $2}'| awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
  if [ -z "${RTT_AVG}" ]; then 
    >&2 echo "ERROR: Cannot retrieve the second number from '${FOURTH_PART}', in the below RTT line:"
    >&2 echo ">${RTT_LINE}"
    exit 1
  fi
  # (e.g.) "97.749/98.197/98.285/0.380"
  RTT_MAX=$(echo "$FOURTH_PART" | awk -F'/' '{print $3}'| awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
  if [ -z "${RTT_MAX}" ]; then 
    >&2 echo "ERROR: Cannot retrieve the third number from '${FOURTH_PART}', in the below RTT line:"
    >&2 echo ">${RTT_LINE}"
    exit 1
  fi
  # (e.g.) "97.749/98.197/98.285/0.380"
  RTT_MDEV=$(echo "$FOURTH_PART" | awk -F'/' '{print $4}'| awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
  if [ -z "${RTT_MDEV}" ]; then 
    >&2 echo "ERROR: Cannot retrieve the fourth number from '${FOURTH_PART}', in the below RTT line:"
    >&2 echo ">${RTT_LINE}"
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

