#!/bin/bash

hex_to_char() {
    printf "\x${1}"
}

hex_to_str(){
    for ((i=0;i<${#1};i+=2));do printf "$(hex_to_char "${1:$i:2}")";done
}

hex_to_int() {
    printf "%d" "$((16#$1))"
}

not_printable() {
    local result
    result=0
    for ((i=0;i<${#1};i+=2));do 
        if [ "$(hex_to_int ${1:i:2})" -lt 32 ] || [ "$(hex_to_int ${1:i:2})" -gt 126 ] #2> /dev/null
        then
            result=1;
            break;
        fi
    done
    printf "$result"
}

decode_length() {
    local input=$1
    local length=$(( (${#input}+1)/2 ))
    local result
    if [ "$length" -eq 0 ]; then
        printf "input is null" >&2
        exit 1
    fi
    prefix=$(printf "%d" "$((16#${input:0:2}))")
    #printf "$prefix $length $((prefix-128))\n"
    if [ "$prefix" -le 127 ]; then #0x7f
        result=(0 2 str)
    elif [ "$prefix" -le 183 ] && [ "$length" -gt $((prefix-128)) ]; then #0xb7
        strLen=$(((prefix-128)*2))
        result=(2 "$strLen" str)
    elif [ "$prefix" -le 191 ] && [ "$length" -gt $((prefix-183)) ] && [ "$length" -gt $((prefix-183+${input:1:$((prefix-183))})) ]; then
        lenOfStrLen=$((prefix-183))
        strLen=${input:1:$lenOfStrLen}
        result=($((1+"$lenOfStrLen")) "$strLen" str)
    elif [ "$prefix" -le 247 ] && [ "$length" -gt $((prefix-192)) ]; then
        listLen=$((prefix-192))
        result=(1 "$listLen" list)
    elif [ "$prefix" -le 255 ] && [ "$length" -gt $((prefix-247)) ] && [ "$length" -gt $((prefix-247+${input:1:$((prefix-247))})) ]; then
        lenOfListLen=$((prefix-247))
        listLen=${input:1:$lenOfListLen}
        result=($((1+"$lenOfListLen")) "$listLen" list)
    else
        printf "input don't conform RLP encoding form" >&2
        exit 1
    fi
    printf "${result[*]}"
}

rlp_decode() {
    input=$1
    if [ "${#input}" -eq 0 ]; then
        return
    fi
    output=""
    IFS=' ' read -r -a arr <<< $(decode_length "${input}")

    offset=${arr[0]}
    dataLen=${arr[1]}
    type=${arr[2]}
    printf "$offset $dataLen $type\n"
    if [ "$type" == "str" ]; then
        output=$(printf "${input:$offset:(($dataLen))}")
        printf "$output\n"
        # if the output contains a hex value that is not a printable ASCII,
        # then treat the entire string as an int
        if [ "$offset" -eq 0 ] || [ "$(not_printable "$output")" -eq "1" ]; then
            printf "$(hex_to_int $output)"
        else
            printf "$(hex_to_str $output)"
        fi
    fi
    #printf "$output"
    
}

#decode_length 83646f67
#hex_to_char 64
#hex_to_int 83
#hex_to_int 80 #0

#rlp_decode 83646f67 #dog works
#rlp_decode 8203e8 #1000 works
#rlp_decode 830186a0 #100000 works
#rlp_decode 21 #33 works
#rlp_decode 15 #21 works
#rlp_decode 01 #1 works
#rlp_decode 7e #126 works
#rlp_decode 8180 128 works
#rlp_decode b74c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c69 # works

#rlp_decode b8384c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c6974 # fails
#rlp_decode b904004c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e73656374657475722061646970697363696e6720656c69742e20437572616269747572206d6175726973206d61676e612c20737573636970697420736564207665686963756c61206e6f6e2c20696163756c697320666175636962757320746f72746f722e2050726f696e20737573636970697420756c74726963696573206d616c6573756164612e204475697320746f72746f7220656c69742c2064696374756d2071756973207472697374697175652065752c20756c7472696365732061742072697375732e204d6f72626920612065737420696d70657264696574206d6920756c6c616d636f7270657220616c6971756574207375736369706974206e6563206c6f72656d2e2041656e65616e2071756973206c656f206d6f6c6c69732c2076756c70757461746520656c6974207661726975732c20636f6e73657175617420656e696d2e204e756c6c6120756c74726963657320747572706973206a7573746f2c20657420706f73756572652075726e6120636f6e7365637465747572206e65632e2050726f696e206e6f6e20636f6e76616c6c6973206d657475732e20446f6e65632074656d706f7220697073756d20696e206d617572697320636f6e67756520736f6c6c696369747564696e2e20566573746962756c756d20616e746520697073756d207072696d697320696e206661756369627573206f726369206c756374757320657420756c74726963657320706f737565726520637562696c69612043757261653b2053757370656e646973736520636f6e76616c6c69732073656d2076656c206d617373612066617563696275732c2065676574206c6163696e6961206c616375732074656d706f722e204e756c6c61207175697320756c747269636965732070757275732e2050726f696e20617563746f722072686f6e637573206e69626820636f6e64696d656e74756d206d6f6c6c69732e20416c697175616d20636f6e73657175617420656e696d206174206d65747573206c75637475732c206120656c656966656e6420707572757320656765737461732e20437572616269747572206174206e696268206d657475732e204e616d20626962656e64756d2c206e6571756520617420617563746f72207472697374697175652c206c6f72656d206c696265726f20616c697175657420617263752c206e6f6e20696e74657264756d2074656c6c7573206c65637475732073697420616d65742065726f732e20437261732072686f6e6375732c206d65747573206163206f726e617265206375727375732c20646f6c6f72206a7573746f20756c747269636573206d657475732c20617420756c6c616d636f7270657220766f6c7574706174 #fails