#!/usr/bin/env python3
"""Mint App Store profile for Settings-iOS, check App Group entitlement, and update GitHub secret."""

from __future__ import annotations

import base64
import json
import os
import plistlib
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

import jwt

API_ROOT = "https://api.appstoreconnect.apple.com"
TEAM_ID = "NA6HPWARQ2"
BUNDLE_ID = "com.itorah.settings"
CERTIFICATE_ID = "B8HSX5CPJ4"
REPO = "davidpovarsky/Settings-iOS"

KEY_PATH = Path(r"C:\Users\DAVID\Downloads\AuthKey_BMFQPP6252.p8")
KEY_ID = "BMFQPP6252"
ISSUER_ID = "b5ac6a24-597d-4c46-924e-712ad41bf667"

now = int(time.time())
token = jwt.encode(
    {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 600,
        "aud": "appstoreconnect-v1",
    },
    KEY_PATH.read_bytes(),
    algorithm="ES256",
    headers={"kid": KEY_ID, "typ": "JWT"},
)
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json",
}


def request(method: str, path: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        f"{API_ROOT}{path}", data=data, headers=headers, method=method
    )
    with urllib.request.urlopen(req, timeout=45) as resp:
        return json.load(resp)


print("1. Checking App Store Connect app record...")
app_query = urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID, "limit": 1})
apps = request("GET", f"/v1/apps?{app_query}").get("data", [])
if not apps:
    print(
        "   [!] App Store Connect app record NOT found yet.\n"
        "       Please create it at: https://appstoreconnect.apple.com/apps\n"
        "       - Name: iTorah Settings (or Settings - iTorah)\n"
        "       - Bundle ID: com.itorah.settings\n"
        "       - SKU: itorah-settings-ios\n"
    )
else:
    print(f"   [OK] App found: '{apps[0]['attributes']['name']}' (ID: {apps[0]['id']})")

print("2. Fetching Bundle ID resource...")
b_query = urllib.parse.urlencode({"filter[identifier]": BUNDLE_ID, "limit": 1})
b_data = request("GET", f"/v1/bundleIds?{b_query}").get("data", [])
if not b_data:
    raise SystemExit(f"Bundle ID {BUNDLE_ID} not found on team {TEAM_ID}")
bundle_resource_id = b_data[0]["id"]
print(f"   [OK] Bundle Resource ID: {bundle_resource_id}")

print("3. Minting new App Store provisioning profile...")
stamp = int(time.time())
profile_name = f"iTorah_Settings_App_Store_{stamp}"
profile_payload = {
    "data": {
        "type": "profiles",
        "attributes": {
            "name": profile_name,
            "profileType": "IOS_APP_STORE",
        },
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": bundle_resource_id}},
            "certificates": {
                "data": [{"type": "certificates", "id": CERTIFICATE_ID}]
            },
        },
    }
}
resp = request("POST", "/v1/profiles", profile_payload)
profile_data = resp["data"]
profile_bytes = base64.b64decode(profile_data["attributes"]["profileContent"])

out_path = Path(r"C:\Users\DAVID\AppleSigning\Settings_App_Store.mobileprovision")
out_path.write_bytes(profile_bytes)
print(f"   [OK] Saved to {out_path}")

# Inspect entitlements
m = re.search(rb"<\?xml.*?</plist>", profile_bytes, re.DOTALL)
if not m:
    raise SystemExit("Could not parse XML plist from profile")
plist = plistlib.loads(m.group(0))
entitlements = plist.get("Entitlements", {})
groups = entitlements.get("com.apple.security.application-groups", [])
print(f"4. Profile application-groups: {groups}")

if "group.com.itorah.shared" not in groups:
    print(
        "\n   [!] 'group.com.itorah.shared' is STILL MISSING from profile entitlements!\n"
        "       Please configure it in the Apple Developer Portal:\n"
        "       1. Visit: https://developer.apple.com/account/resources/identifiers/bundleId/edit/KC6ZV9XTP8\n"
        "       2. Under Capabilities, locate 'App Groups' and click 'Configure'\n"
        "       3. Check the checkbox for 'group.com.itorah.shared'\n"
        "       4. Click 'Continue' and 'Save'\n"
        "       5. Re-run this script!\n"
    )
    sys.exit(1)

print("   [OK] 'group.com.itorah.shared' is present in profile entitlements!")

b64_profile = base64.b64encode(profile_bytes).decode("ascii")
print(f"5. Updating GitHub Secret 'APPLE_MAIN_PROVISIONING_PROFILE_B64' in {REPO}...")
cmd = ["gh", "secret", "set", "APPLE_MAIN_PROVISIONING_PROFILE_B64", "--repo", REPO]
proc = subprocess.run(cmd, input=b64_profile, text=True, capture_output=True)
if proc.returncode != 0:
    print(f"   [!] Failed to set secret: {proc.stderr}")
    sys.exit(1)
print("   [OK] Secret updated successfully!")

print("\nAll prerequisites met! Ready to trigger TestFlight workflow.")
