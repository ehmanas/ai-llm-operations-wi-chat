# Encrypting decrypting json data

1. First, generate the key pair in PEM format:
```bash
# Generate private key
openssl genpkey -algorithm RSA -out private.pem -pkeyopt rsa_keygen_bits:4096

# Generate public key
openssl rsa -in private.pem -pubout -out public.pem
```

2. Then encrypt:
```bash
echo '{"name":"John","age":30}' | openssl pkeyutl -encrypt -pubin -inkey public.pem | openssl enc -base64 -A | jq -Rr @uri > encrypted.value
```

3. And decrypt:
```bash
cat encrypted.value \
  | python3 -c '
import sys, urllib.parse, base64
data = sys.stdin.read()             # read URL-escaped Base64 from stdin
data = urllib.parse.unquote(data)   # url-decode
data = base64.b64decode(data)       # base64-decode
sys.stdout.buffer.write(data)       # write raw bytes to stdout
' \
  | openssl pkeyutl -decrypt -inkey private.pem
```
