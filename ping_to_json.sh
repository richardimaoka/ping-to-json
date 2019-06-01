#!/bin/sh

# ----------------------------------------------------------------------------------------
# You pass the whole ping output as input stream, and this produces the JSON of it.
# You can do like this (e.g.):
#   ping -c 5 google.com | ping-script/ping_to_json.sh | jq
# ----------------------------------------------------------------------------------------

# cd to the current directory as it runs other shell scripts
cd "$(dirname "$0")" || exit

while read -r line; do
  if echo "${line}" | grep "bytes from" | grep "icmp_seq=" | grep "ttl=" | grep -q "time=" ; then
    if [ -z "${ICMP_SEQUENCES}" ]; then
      ICMP_SEQUENCES="$(echo "${line}" | ./icmp_line.sh)"
    else
      ICMP_SEQUENCES="${ICMP_SEQUENCES}, $(echo "${line}" | ./icmp_line.sh)"
    fi
  elif echo "${line}" | grep -q "rtt min/avg/max/mdev" ; then
    if [ -n "${RTT_STATISTICS_JSON}" ]; then
      >&2 echo "ERROR: There must be only one RTT statistics line, but '${line}' appeared as another one. Previous RTT statistics is:"
      >&2 echo "${RTT_STATISTICS_JSON}"
      exit 1
    else
      RTT_STATISTICS_JSON="$(echo "${line}" | ./rtt_statistics.sh)"
    fi
  elif echo "${line}" | grep "packets transmitted, " | grep "received, " | grep " packet loss, " | grep -q "time " ; then
    if [ -n "${RTT_SUMMARY_JSON}" ]; then
      >&2 echo "ERROR: There must be only one RTT summary line, but '${line}' appeared as another one. Previous RTT summary is:"
      >&2 echo "${RTT_SUMMARY_JSON}"
      exit 1
    else
      RTT_SUMMARY_JSON="$(echo "${line}" | ./rtt_summary.sh)"
   fi
  fi
done < /dev/stdin


if [ -z "${RTT_STATISTICS_JSON}" ]; then
  >&2 echo "ERROR: RTT statistics line is not found, which starts with rtt min/avg/max/mdev"
  exit 1
elif  [ -z "${RTT_SUMMARY_JSON}" ]; then
  >&2 echo "ERROR: RTT summary line is not found, which is like '** packets transmitted, ** received, *% packet loss, time ****ms'"
  exit 1
fi

echo "{"
echo "  \"rtt_summary\": ${RTT_SUMMARY_JSON},"
echo "  \"rtt_statistics\": ${RTT_STATISTICS_JSON},"
echo "  \"icmp_sequences\": [${ICMP_SEQUENCES}]"
echo "}"