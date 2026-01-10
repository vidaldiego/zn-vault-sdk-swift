#!/bin/bash
# Path: zn-vault-sdk-swift/test-integration.sh
# Integration tests for ZnVault Swift SDK (API compatibility testing)

# Don't exit on error - we want to run all tests

BASE_URL="https://localhost:8443"
CURL="curl -sk"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

test_result() {
    local name=$1
    local status=$2
    if [ "$status" -eq 0 ]; then
        echo -e "${GREEN}✅ PASSED${NC}: $name"
        ((PASSED++))
    else
        echo -e "${RED}❌ FAILED${NC}: $name"
        ((FAILED++))
    fi
}

echo ""
echo "========================================"
echo "ZnVault Swift SDK Integration Tests"
echo "========================================"
echo ""

# Test 1: Health Check
echo "Testing: Health Check..."
HEALTH=$($CURL "$BASE_URL/v1/health")
if echo "$HEALTH" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('status')=='ok' else 1)" 2>/dev/null; then
    test_result "Health Check" 0
    echo "   Status: $(echo "$HEALTH" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status'))")"
else
    test_result "Health Check" 1
fi

# Test 2: Login
echo ""
echo "Testing: Login..."
LOGIN_RESPONSE=$($CURL -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"Admin123456#"}')

if echo "$LOGIN_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('accessToken') else 1)" 2>/dev/null; then
    test_result "Login" 0
    ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('accessToken'))")
    echo "   Got access token: ${ACCESS_TOKEN:0:30}..."
else
    test_result "Login" 1
    echo "   Response: $LOGIN_RESPONSE"
    exit 1
fi

AUTH_HEADER="Authorization: Bearer $ACCESS_TOKEN"

# Test 3: Get Current User (response has nested 'user' object)
echo ""
echo "Testing: Get Current User..."
ME_RESPONSE=$($CURL -H "$AUTH_HEADER" "$BASE_URL/auth/me")
if echo "$ME_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('user',{}).get('username') else 1)" 2>/dev/null; then
    test_result "Get Current User" 0
    echo "   Username: $(echo "$ME_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('user',{}).get('username'))")"
else
    test_result "Get Current User" 1
    echo "   Response: $ME_RESPONSE"
fi

# Test 4: Create Secret
echo ""
echo "Testing: Create Secret..."
TIMESTAMP=$(date +%s)
SECRET_ALIAS="swift-test/secret-$TIMESTAMP"
CREATE_SECRET_RESPONSE=$($CURL -X POST "$BASE_URL/v1/secrets" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{\"alias\":\"$SECRET_ALIAS\",\"tenant\":\"zincapp\",\"type\":\"credential\",\"data\":{\"username\":\"testuser\",\"password\":\"testpass\"}}")

if echo "$CREATE_SECRET_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('id') else 1)" 2>/dev/null; then
    test_result "Create Secret" 0
    SECRET_ID=$(echo "$CREATE_SECRET_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id'))")
    echo "   Created secret: $SECRET_ID"
else
    test_result "Create Secret" 1
    echo "   Response: $CREATE_SECRET_RESPONSE"
fi

# Test 5: Get Secret Metadata (use /{id}/meta endpoint - the only way to get by ID)
echo ""
echo "Testing: Get Secret Metadata..."
GET_SECRET_RESPONSE=$($CURL -H "$AUTH_HEADER" "$BASE_URL/v1/secrets/$SECRET_ID/meta")
if echo "$GET_SECRET_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('alias') else 1)" 2>/dev/null; then
    test_result "Get Secret Metadata" 0
    echo "   Alias: $(echo "$GET_SECRET_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('alias'))")"
    echo "   Version: $(echo "$GET_SECRET_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('version'))")"
else
    test_result "Get Secret Metadata" 1
    echo "   Response: $GET_SECRET_RESPONSE"
fi

# Test 6: Get Secret by Tenant/Alias path (returns metadata, not decrypted data)
echo ""
echo "Testing: Get Secret by Alias..."
# URL encode the alias (replace / with %2F)
ENCODED_ALIAS=$(echo "$SECRET_ALIAS" | sed 's/\//%2F/g')
GET_BY_ALIAS_RESPONSE=$($CURL -H "$AUTH_HEADER" "$BASE_URL/v1/secrets/zincapp/$ENCODED_ALIAS")
if echo "$GET_BY_ALIAS_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('alias') else 1)" 2>/dev/null; then
    test_result "Get Secret by Alias" 0
    echo "   ID: $(echo "$GET_BY_ALIAS_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id'))")"
    echo "   Alias: $(echo "$GET_BY_ALIAS_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('alias'))")"
else
    test_result "Get Secret by Alias" 1
    echo "   Response: $GET_BY_ALIAS_RESPONSE"
fi

# Test 7: Update Secret
echo ""
echo "Testing: Update Secret..."
UPDATE_RESPONSE=$($CURL -X PUT "$BASE_URL/v1/secrets/$SECRET_ID" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d '{"data":{"username":"updated","password":"newpass"}}')
if echo "$UPDATE_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('version')==2 else 1)" 2>/dev/null; then
    test_result "Update Secret" 0
    echo "   New version: $(echo "$UPDATE_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('version'))")"
else
    test_result "Update Secret" 1
    echo "   Response: $UPDATE_RESPONSE"
fi

# Test 8: List Secrets (response is an array, not {data: []})
echo ""
echo "Testing: List Secrets..."
LIST_SECRETS_RESPONSE=$($CURL -H "$AUTH_HEADER" "$BASE_URL/v1/secrets?tenant=zincapp&limit=5")
if echo "$LIST_SECRETS_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if isinstance(d, list) else 1)" 2>/dev/null; then
    test_result "List Secrets" 0
    echo "   Found: $(echo "$LIST_SECRETS_RESPONSE" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")"
else
    test_result "List Secrets" 1
    echo "   Response: ${LIST_SECRETS_RESPONSE:0:100}..."
fi

# Test 9: Delete Secret
echo ""
echo "Testing: Delete Secret..."
DELETE_RESPONSE=$($CURL -X DELETE -w "%{http_code}" -o /dev/null "$BASE_URL/v1/secrets/$SECRET_ID" -H "$AUTH_HEADER")
if [ "$DELETE_RESPONSE" == "200" ] || [ "$DELETE_RESPONSE" == "204" ]; then
    test_result "Delete Secret" 0
    echo "   Deleted successfully"
else
    test_result "Delete Secret" 1
    echo "   HTTP status: $DELETE_RESPONSE"
fi

# Test 10: Create KMS Key (requires tenant parameter)
echo ""
echo "Testing: Create KMS Key..."
KEY_ALIAS="alias/swift-test-$TIMESTAMP"
CREATE_KEY_RESPONSE=$($CURL -X POST "$BASE_URL/v1/kms/keys" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{\"alias\":\"$KEY_ALIAS\",\"tenant\":\"zincapp\",\"keySpec\":\"AES_256\",\"usage\":\"ENCRYPT_DECRYPT\",\"description\":\"Swift SDK test key\"}")

if echo "$CREATE_KEY_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('keyId') else 1)" 2>/dev/null; then
    test_result "Create KMS Key" 0
    KEY_ID=$(echo "$CREATE_KEY_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('keyId'))")
    echo "   Created key: $KEY_ID"
else
    test_result "Create KMS Key" 1
    echo "   Response: $CREATE_KEY_RESPONSE"
fi

# Test 11: KMS Encrypt (requires context parameter)
echo ""
echo "Testing: KMS Encrypt..."
PLAINTEXT=$(echo -n "Hello from Swift!" | base64)
ENCRYPT_RESPONSE=$($CURL -X POST "$BASE_URL/v1/kms/encrypt" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{\"keyId\":\"$KEY_ID\",\"plaintext\":\"$PLAINTEXT\",\"context\":{}}")

if echo "$ENCRYPT_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('ciphertext') else 1)" 2>/dev/null; then
    test_result "KMS Encrypt" 0
    CIPHERTEXT=$(echo "$ENCRYPT_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ciphertext'))")
    echo "   Encrypted: ${CIPHERTEXT:0:30}..."
else
    test_result "KMS Encrypt" 1
    echo "   Response: $ENCRYPT_RESPONSE"
fi

# Test 12: KMS Decrypt (requires context parameter)
echo ""
echo "Testing: KMS Decrypt..."
DECRYPT_KMS_RESPONSE=$($CURL -X POST "$BASE_URL/v1/kms/decrypt" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{\"keyId\":\"$KEY_ID\",\"ciphertext\":\"$CIPHERTEXT\",\"context\":{}}")

if echo "$DECRYPT_KMS_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('plaintext') else 1)" 2>/dev/null; then
    test_result "KMS Decrypt" 0
    DECRYPTED=$(echo "$DECRYPT_KMS_RESPONSE" | python3 -c "import json,sys; import base64; print(base64.b64decode(json.load(sys.stdin).get('plaintext')).decode('utf-8'))")
    echo "   Decrypted: $DECRYPTED"
else
    test_result "KMS Decrypt" 1
    echo "   Response: $DECRYPT_KMS_RESPONSE"
fi

# Test 13: List KMS Keys (requires tenant parameter)
echo ""
echo "Testing: List KMS Keys..."
LIST_KEYS_RESPONSE=$($CURL -H "$AUTH_HEADER" "$BASE_URL/v1/kms/keys?tenant=zincapp&limit=5")
if echo "$LIST_KEYS_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if isinstance(d.get('keys'), list) else 1)" 2>/dev/null; then
    test_result "List KMS Keys" 0
    echo "   Found: $(echo "$LIST_KEYS_RESPONSE" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('keys',[])))")"
else
    test_result "List KMS Keys" 1
    echo "   Response: ${LIST_KEYS_RESPONSE:0:100}..."
fi

# Test 14: List Audit Logs (response has 'entries' not 'data')
echo ""
echo "Testing: List Audit Logs..."
LIST_AUDIT_RESPONSE=$($CURL -H "$AUTH_HEADER" "$BASE_URL/v1/audit?limit=5")
if echo "$LIST_AUDIT_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if 'entries' in d else 1)" 2>/dev/null; then
    test_result "List Audit Logs" 0
    echo "   Found: $(echo "$LIST_AUDIT_RESPONSE" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('entries',[])))")"
else
    test_result "List Audit Logs" 1
    echo "   Response: ${LIST_AUDIT_RESPONSE:0:100}..."
fi

# Test 15: Verify Audit Chain
echo ""
echo "Testing: Verify Audit Chain..."
VERIFY_RESPONSE=$($CURL -H "$AUTH_HEADER" "$BASE_URL/v1/audit/verify")
if echo "$VERIFY_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('valid') else 1)" 2>/dev/null; then
    test_result "Verify Audit Chain" 0
    echo "   Chain valid: $(echo "$VERIFY_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('valid'))")"
else
    test_result "Verify Audit Chain" 1
    echo "   Response: $VERIFY_RESPONSE"
fi

# Test 16: List Tenants (using /v1/tenants not /v1/admin/tenants)
echo ""
echo "Testing: List Tenants..."
LIST_TENANTS_RESPONSE=$($CURL -H "$AUTH_HEADER" "$BASE_URL/v1/tenants?limit=5")
if echo "$LIST_TENANTS_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if isinstance(d, list) or 'tenants' in d or 'data' in d else 1)" 2>/dev/null; then
    test_result "List Tenants" 0
    COUNT=$(echo "$LIST_TENANTS_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else len(d.get('tenants',d.get('data',[]))))")
    echo "   Found: $COUNT"
else
    test_result "List Tenants" 1
    echo "   Response: ${LIST_TENANTS_RESPONSE:0:100}..."
fi

# Test 17: List Users (response has 'admins' key)
echo ""
echo "Testing: List Users..."
LIST_USERS_RESPONSE=$($CURL -H "$AUTH_HEADER" "$BASE_URL/v1/admin/users?limit=5")
if echo "$LIST_USERS_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if 'admins' in d or 'users' in d or 'data' in d else 1)" 2>/dev/null; then
    test_result "List Users" 0
    COUNT=$(echo "$LIST_USERS_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('admins',d.get('users',d.get('data',[])))))")
    echo "   Found: $COUNT"
else
    test_result "List Users" 1
    echo "   Response: ${LIST_USERS_RESPONSE:0:100}..."
fi

# Test 18: List Roles
echo ""
echo "Testing: List Roles..."
LIST_ROLES_RESPONSE=$($CURL -H "$AUTH_HEADER" "$BASE_URL/v1/roles?limit=5")
if echo "$LIST_ROLES_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if isinstance(d, list) or 'data' in d or 'roles' in d else 1)" 2>/dev/null; then
    test_result "List Roles" 0
    COUNT=$(echo "$LIST_ROLES_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else len(d.get('data',d.get('roles',[]))))")
    echo "   Found: $COUNT"
else
    test_result "List Roles" 1
    echo "   Response: ${LIST_ROLES_RESPONSE:0:100}..."
fi

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo ""
echo -e "${GREEN}✅ Passed: $PASSED${NC}"
echo -e "${RED}❌ Failed: $FAILED${NC}"
echo "📊 Total:  $((PASSED + FAILED))"
echo ""
echo "========================================"
echo ""

if [ $FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi
