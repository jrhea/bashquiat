#!/bin/bash

source $PWD/rlp/encode.sh

i=0
out=$(grep -o '\"out\": .*' $PWD/rlp/tests/tests.json | cut -d: -f2 | sed 's/^ *//g' | tr -d "\"" | tr "\n" "|")
IFS='|' read -r -a outputs <<< "$out"

in=$(grep -o '\"in\": .*,' $PWD/rlp/tests/tests.json | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$/|/' | tr -d "\"" | tr -d "\n")
IFS='|' read -r -a inputs <<< "$in"
for input in "${inputs[@]}"; do
    printf "%s\n" "TEST CASE: $i"
    printf "%s\n" "$input"
    printf "%s\n" $(rlp_encode "$input")
    printf "%s\n" "${outputs[$i]}"
    printf "%s\n" ""
    (( i+=1 ))
done