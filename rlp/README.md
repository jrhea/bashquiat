# RLP in Bash

This code implements the RLP specification in Bash. This uses pure Bash where possible, but in some cases I am forced to use core-utils.

#### 🚧 This is a WIP 🚧

## Usage

### Encoding

```bash
$ source rlp/codec.sh 
$ rlp_encode ["dog","god","cat"]
cc83646f6783676f6483636174
```

### Decoding

```bash
$ source rlp/codec.sh 
$ rlp_decode cc83646f6783676f6483636174
[dog,god,cat]
```

## Code

The following code demonstrates how to encode/decode a message to/from RLP:

```bash
#!/bin/bash

source codec.sh

# Encode message into RLP
local encoded_message=$(rlp_encode "[\"dog\",\"god\",\"cat\"]")

# Outputs: cc83646f6783676f6483636174
printf '%s' $encoded_message

local decoded_message=$(rlp_decode "$encoded_message")

# Outputs: ["dog","god","cat"]
printf '%s' $decoded_message

```

## Test

To test the codec, run the following command from this directory:

```bash
chmod +x rlp/tests/run_tests.sh 
./rlp/tests/run_tests.sh
```
