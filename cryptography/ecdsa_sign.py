import argparse
import binascii
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

def ecdsa_sign(message, private_key):
    # Convert hex inputs to bytes
    message_bytes = binascii.unhexlify(message)
    private_key_bytes = binascii.unhexlify(private_key)

    # Load the private key
    private_key_int = int.from_bytes(private_key_bytes, byteorder='big')
    private_key_obj = ec.derive_private_key(private_key_int, ec.SECP256K1())

    # Sign the message
    signature_der = private_key_obj.sign(message_bytes, ec.ECDSA(hashes.SHA256()))

    # Convert DER signature to raw r || s format
    r, s = decode_dss_signature(signature_der)
    r_bytes = r.to_bytes(32, byteorder='big')
    s_bytes = s.to_bytes(32, byteorder='big')
    signature_raw = r_bytes + s_bytes

    return signature_raw.hex()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='ECDSA Signing')
    parser.add_argument('message', help='Message to sign (hex)')
    parser.add_argument('private_key', help='Private key (hex)')
    args = parser.parse_args()

    try:
        signature = ecdsa_sign(args.message, args.private_key)
        print(signature)
    except binascii.Error:
        print("Error: Invalid hexadecimal input", file=sys.stderr)
        sys.exit(1)
    except ValueError as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)