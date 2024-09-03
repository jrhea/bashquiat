# RLP in Bash

This code implements the RLP specification in Bash. This uses pure Bash where possible, but in some cases I was forced to use core-utils like `bc` and `sed` in certain cases.

> Note: This was written and tested on Linux so no guarantees that it will work on MacOS

## Test

To test the codec, run the following command from this directory:

```bash
chmod +x tests/run_tests.sh 
./tests/run_test.sh
```
