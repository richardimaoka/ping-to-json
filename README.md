## Instruction:

```
> git clone 
> ping google.com | ping-to-json/ping-to-json.sh

# You can also use `jq` for better formatting and further processing 
# > ping google.com | ping-to-json/ping-to-json.sh | jq
```

and get the output like below:

```
{
  "rtt_summary": {
    "packets_transmitted": 5,
    "packets_received": 5,
    "packet_loss_percentage": 0,
    "time": {
      "unit": "milliseconds",
      "value": 4004
    }
  },
  "rtt_statistics": {
    "min": {
      "value": "7.590",
      "unit": "milliseconds"
    },
    "avg": {
      "value": "10.362",
      "unit": "milliseconds"
    },
    "max": {
      "value": "18.049",
      "unit": "milliseconds"
    },
    "mdev": {
      "value": "3.870",
      "unit": "milliseconds"
    }
  },
  "icmp_sequences": [
    {
      "bytes": 64,
      "target": "nrt12s17-in-f46.1e100.net",
      "target_ip": "172.217.26.46",
      "icmp_seq": 1,
      "ttl": 57,
      "time": {
        "unit": "milliseconds",
        "value": 8.69
      }
    },
    {
      "bytes": 64,
      "target": "nrt12s17-in-f46.1e100.net",
      "target_ip": "172.217.26.46",
      "icmp_seq": 2,
      "ttl": 57,
      "time": {
        "unit": "milliseconds",
        "value": 8.66
      }
    },
    {
      "bytes": 64,
      "target": "nrt12s17-in-f46.1e100.net",
      "target_ip": "172.217.26.46",
      "icmp_seq": 3,
      "ttl": 57,
      "time": {
        "unit": "milliseconds",
        "value": 18
      }
    },
    {
      "bytes": 64,
      "target": "nrt12s17-in-f46.1e100.net",
      "target_ip": "172.217.26.46",
      "icmp_seq": 4,
      "ttl": 57,
      "time": {
        "unit": "milliseconds",
        "value": 7.59
      }
    },
    {
      "bytes": 64,
      "target": "nrt12s17-in-f46.1e100.net",
      "target_ip": "172.217.26.46",
      "icmp_seq": 5,
      "ttl": 57,
      "time": {
        "unit": "milliseconds",
        "value": 8.81
      }
    }
  ]
}
```

where the normal ping output is like:

```
PING google.com (172.217.26.46) 56(84) bytes of data.
64 bytes from nrt12s17-in-f46.1e100.net (172.217.26.46): icmp_seq=1 ttl=57 time=8.69 ms
64 bytes from nrt12s17-in-f46.1e100.net (172.217.26.46): icmp_seq=2 ttl=57 time=8.66 ms
64 bytes from nrt12s17-in-f46.1e100.net (172.217.26.46): icmp_seq=3 ttl=57 time=18.0 ms
64 bytes from nrt12s17-in-f46.1e100.net (172.217.26.46): icmp_seq=4 ttl=57 time=7.59 ms
64 bytes from nrt12s17-in-f46.1e100.net (172.217.26.46): icmp_seq=5 ttl=57 time=8.81 ms

--- google.com ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4004ms
rtt min/avg/max/mdev = 7.590/10.362/18.049/3.870 ms
```

## Prerequisite:

`sed` and `awk` are required. `jq` is not needed unless you pipe the output to the `jq` command like this:

```
>ping google.com | ping-to-json/ping-to-json.sh
```

## Why did I write this?

While working on my ping experiment for [my blog article](https://richardimaoka.github.io/blog/network-latency-analysis-with-ping-aws/), I started feeling it will be much more convenient to convert the ping output into a json, for automatic data collection and processing.

I tried to find an existing tool, but surprisingly or not, I could find only one such tool:

https://pypi.org/project/pingparsing/

pingparsing is written in Python, and looked neat and useful. However, I wanted a shell script which has less dependencies so that I can run it on a broader range of environments.

My script is not as mature as pingparsing, so please let me know any case my shell script is not parsing the correct ping output.
