#!/usr/bin/env bash
# Usage: ADMOB_APP_ID=ca-app-pub-xxx~yyy ./scripts/setup-android.sh
# Run after `npm run android:add`. Injects the AdMob app id + billing permission into the Android project.
set -e
M=android/app/src/main/AndroidManifest.xml
ID="${ADMOB_APP_ID:-ca-app-pub-3940256099942544~3347511713}"   # default = Google TEST app id
[ -f "$M" ] || { echo "Run npm run android:add first"; exit 1; }
if ! grep -q "gms.ads.APPLICATION_ID" "$M"; then
  sed -i "s#</application>#    <meta-data android:name=\"com.google.android.gms.ads.APPLICATION_ID\" android:value=\"$ID\"/>\n    </application>#" "$M"
fi
grep -q "com.android.vending.BILLING" "$M" || sed -i "s#</manifest>#    <uses-permission android:name=\"com.android.vending.BILLING\"/>\n</manifest>#" "$M"
echo "Patched $M with AdMob id $ID"
