#!/bin/bash

str2hex() {
    # USAGE: str2hex "ABC"
    #        returns "414243"
    local str=${1:-""}
    local fmt="%x"
    local chr
    local -i i
    for i in `seq 0 $((${#str}-1))`; do
        chr=${str:i:1}
        # If the leading character is a single-quote or double-quote, the value shall be the numeric value in the underlying codeset of the character following the single-quote or double-quote
        printf  "${fmt}" "'${chr}"
    done
}

# protocol header

protocol_id=$(printf "discv5" |  hexdump -ve '1/1 "%.2x"')
printf "protocol_id=$protocol_id\n"
version=0001
printf "version=$version\n"
flag=01
printf "flag=$flag\n"
# output random 12 bytes. hexdump format string ensures there are no spaces
nonce=$(dd if=/dev/urandom  bs=1 count=12 2>/dev/null| hexdump -ve '1/1 "%.2x"')
printf "nonce=$nonce\n"
authdata_size=0018 # 24 represented as 2 bytes (23 total)
printf "authdata_size=$authdata_size\n"
static_header="$protocol_id$version$flag$nonce$authdata_size"
printf "static_header=$static_header\n"
printf $static_header | wc -m
#printf $static_header | xxd -r -p