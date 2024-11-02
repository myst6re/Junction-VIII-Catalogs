#!/bin/bash
output=""
ret=0
declare -A id_map

# Initialize the validation results file
echo -e "### Validtion Results" > validation_results.md

for file in mods/**/*.xml; do
  IFS='/'
  read -ra parts <<< "$file"
  name="${parts[1]}"
  warnings=""
  errors=""
  
  # Lint the XML file
  xmllint --noout "$file"
  if [ $? -ne 0 ]; then
    errors+=" - Invalid XML failed lint\n"
    ret=1
  fi
  
  # Check Mod.LatestVersion.Link
  latest_version_link=$(xmllint --xpath 'string(//Mod/LatestVersion/Link)' "$file" | sed 's|iroj://Url/https\$|https://|' | sed 's|iroj://Url/http\$|http://|')
  curl --output /dev/null --silent --head --fail "$latest_version_link" -A "Mozilla/5.0"
  if [ $? -ne 0 ]; then
    errors+=" - Verify LatestVersion.Link failed: [link]($latest_version_link)\n"
    ret=1
  fi

  # Check Mod.LatestVersion.PreviewImage
  preview_image=$(xmllint --xpath 'string(//Mod/LatestVersion/PreviewImage)' "$file")
  if [ -n "$preview_image" ]; then
    curl --head --fail -H "Accept: image/*" "$preview_image" -A "Mozilla/5.0" --silent | grep "content-type: blar/*"
    if [ $? -ne 0 ]; then
      warnings+=" - Verify Mod.PreviewImage failed: [preview image]($preview_image)\n"
    fi
  fi

  # Check Mod.Link
  mod_link=$(xmllint --xpath 'string(//Mod/Link)' "$file")
  if [ -n "$mod_link" ]; then
    curl --output /dev/null --silent --head --fail "$mod_link" -A "Mozilla/5.0"
    if [ $? -ne 0 ]; then
      warnings+=" - Verify Mod.Link failed: [link]($mod_link)\n"
    fi
  fi

  # Check Mod.DonationLink
  donation_link=$(xmllint --xpath 'string(//Mod/DonationLink)' "$file")
  if [ -n "$donation_link" ]; then
    curl --output /dev/null --silent --head --fail "$donation_link" -A "Mozilla/5.0"
    if [ $? -ne 0 ]; then
      warnings+=" - Verify Mod.DonationLink failed: [donation link]($donation_link)\n"
    fi
  fi

  # Check for unique ID
  mod_id=$(xmllint --xpath 'string(//Mod/ID)' "$file")
  if [ -n "${id_map[$mod_id]}" ]; then
    errors+=" - Duplicate Mod ID found: $mod_id (conflicts with ${id_map[$mod_id]})\n"
    ret=1
  else
    id_map[$mod_id]=$name
  fi

  # Append results to the output file
  if [ -n "$errors" ]; then
    echo -e "#### Mod: $name 🔴\n" >> validation_results.md
  elif [ -n "$warnings" ]; then
    echo -e "#### Mod: $name 🟡\n" >> validation_results.md
  else
    echo -e "#### Mod: $name 🟢\n" >> validation_results.md
    echo -e "No errors or warnings\n" >> validation_results.md
  fi

  if [ -n "$errors" ]; then
    echo -e "Errors:\n$errors\n" >> validation_results.md
  fi
  if [ -n "$warnings" ]; then
    echo -e "Warnings:\n$warnings\n" >> validation_results.md
  fi
done

exit $ret