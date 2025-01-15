#!/bin/bash  

# Build the Move package  
if ! sui move build; then  
    echo "Move build failed."  
    exit 1  
fi  

# Publish the package and output to sui-build.json  
if ! sui client publish --gas-budget 100000000 --force --json > sui-build.json; then  
    echo "Failed to publish the package."  
    exit 1  
fi  

# Create or clear the .env file  
> .env  

# Extract necessary values and append them to the .env file  
{  
  jq '.objectChanges[] | select(.objectType=="0x2::package::UpgradeCap") | .objectId' sui-build.json | awk '{print "ORIGINAL_UPGRADE_CAP_ID="$1}';  
  jq '.objectChanges[].packageId | select(. != null)' sui-build.json | awk '{print "PACKAGE_ID="$1}';  
  sui client gas --json | jq '.[-1].gasCoinId' | awk '{printf "SUI_FEE_COIN_ID=%s\n",$1}';  
  sui client active-address | awk '{printf "ACCOUNT_ID1=\"%s\"\n",$1}';  
  jq '.objectChanges[].packageId | select(. != null) | {packageId: .} | {QUOTE_COIN_TYPE: .packageId}' sui-build.json | awk '{printf "QUOTE_COIN_TYPE=\"%s::wbtc::WBTC\"\n",$1}';  
} >> .env  

# Source the .env file to make the variables available in the current session  
source .env  

echo ".env file created and sourced successfully."