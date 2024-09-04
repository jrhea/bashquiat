#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/../utils/utils.sh

aesctr_encrypt() {
    local plaintext="$1"
    local key="$2"
    local iv="$3"
    printf '%s' "$plaintext" | openssl enc -aes-256-ctr -K "$key" -iv "$iv" | hexdump -ve '1/1 "%.2x"'
}

# packet        = masking-iv || masked-header || message
packet() {
    masking_iv=$1
    masking_key=$2
    header=$3
    masked_header=$(masked_header $masking_key $masking_iv $header)
    message=$4
    printf "$masking_iv$masked_header$message"
}

# masked-header = aesctr_encrypt(masking-key, masking-iv, header)
# masking-key   = dest-id[:16]
# masking-iv    = uint128   -- random data unique to packet
masked_header() {
    masking_key=$1
    masking_iv=$2
    header=$3
    printf $(aesctr_encrypt "$header" "$masking_key" "$masking_iv")
}

# header        = static-header || authdata
header(){
    static_header=$1
    authdata=$2
    printf "$static_header$authdata"
}

# static-header = protocol-id || version || flag || nonce || authdata-size
# protocol-id   = "discv5"
# version       = 0x0001
# authdata-size = uint16    -- byte length of authdata
# flag          = uint8     -- packet type identifier
# nonce         = uint96    -- nonce of message
static_header() {
    # convert protocol_id to hex
    protocol_id=$(printf "discv5" | hexdump -ve '1/1 "%.2x"')
    version=0001
    flag=$1
    nonce=$2
    authdata_size=$3
    printf "$protocol_id$version$flag$nonce$authdata_size"
}

ordinary_message_packet() {
    nonce=$1
    source_node_id=$2
    masking_iv=$3
    dest_node_id=$4
    flag=00
    authdata_size=0020 # 32 represented as 2 bytes (31 total)
    static_header=$(static_header $flag $nonce $authdata_size)
    header=$(header $source_node_id $static_header)
    packet=$(packet $masking_iv $dest_node_id $header)
    printf "packet=$packet\n"
}

SOURCE_NODE_ID="aaaa8419e9f49d0083561b48287df592939a8d19947d8c0ef88f2a4856a69fbb"
DEST_NODE_ID="bbbb9d047f0488c0b5a93c1c3f2d8bafc7c8ff337024a55434a0d0555de64db9"
# output random 12 bytes. hexdump format string ensures there are no spaces
NONCE=$(dd if=/dev/urandom  bs=1 count=12 2>/dev/null | hexdump -ve '1/1 "%.2x"')
# output random 16 bytes. hexdump format string ensures there are no spaces
MASKING_IV=$(dd if=/dev/urandom  bs=1 count=16 2>/dev/null | hexdump -ve '1/1 "%.2x"')
ordinary_message_packet $NONCE $SOURCE_NODE_ID $MASKING_IV $DEST_NODE_ID
#encrypted=$(aesctr_encrypt "This is a secret message." $DEST_NODE_ID $masking_iv)
#printf '%s' "$encrypted" | xxd -p -r | openssl enc -aes-256-ctr -d -K "$DEST_NODE_ID" -iv "$masking_iv"
