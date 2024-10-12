import sys
import binascii
from Crypto.Hash import keccak

def keccak_hash(data):
    data = binascii.unhexlify(data)

    # Create a new Keccak hash object
    k = keccak.new(digest_bits=256)

    # Update the hash object with the data
    k.update(data)

    # Return the hexadecimal representation of the hash
    return k.hexdigest()

if __name__ == "__main__":
    if len(sys.argv) < 1:
        print("Usage: keccak_hash.py <input_data> [hash_bits]")
        print("  <input_data>: The data to hash (string or hex)")
        sys.exit(1)
    
    input_data = sys.argv[1]

    try:
        result = keccak_hash(input_data)
        print(result)
    except Exception as e:
        print(f"Error: {str(e)}")
        sys.exit(1)