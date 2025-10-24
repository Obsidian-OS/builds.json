#!/bin/bash
set -euo pipefail
echo -e "\033[0;38;2;0;255;155;49m\r"
cat<<EOF
bdj - builds.json auto-downloader
Copyright (c) 2025 ObsidianOS
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
EOF
# Check dependencies
for cmd in curl gpg kitten jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "You need $cmd."
    exit 1
  fi
done
# Download builds.json
: "${root:=https://files.obsidianos.xyz}"
: "${builds:=${root}/builds.json}"
: "${distributerName:=ObsidianOS}"
# GPG signer
: "${signer:=BC55E14F8C660615803C3BFC9B41151A96BBBF97}"
: "${signerKeyserver:=hkps://keyserver.ubuntu.com}"
: "${usegpg:=yes}"

# Step 1: Import GPG key if missing
echo -e "\033[0;38;2;222;222;225;49mbuilds.json is:"
echo "$builds"
echo "root is:"
echo "$root/"
echo "you are using a version of bdj from ${distributerName}"
if [ "$usegpg" = yes ]; then
    if ! gpg --list-keys --with-colons | grep -q "$signer"; then
        read -rp "Download GPG key $signer from $signerKeyserver? [y/N] " ans
        if [[ $ans =~ ^[yY]$ ]]; then
            gpg --keyserver "$signerKeyserver" --recv-keys "$signer"
        else
            usegpg="no"
        fi
   fi
fi
builds="$(curl -s $builds)"
echo -e "\033[0;38;2;0;111;222;49m"
# Step 2: Show builds table
options=$(echo "$builds" | jq 'length')
echo "There are $options options:"
printf "%-3s %-15s %s\n" "ID" "Edition" "Description"
echo "-----------------------------------------------"
for i in $(seq 0 $((options - 1))); do
    name=$(echo "$builds" | jq -r ".[$i].name")
    desc=$(echo "$builds" | jq -r ".[$i].info")
    curl -s $(echo "$builds" | jq -r ".[$i].icon_url") | kitten icat --align=left --use-window-size=10,10,50,50
    printf "%-3s %-15s %s\n" "$i:" "$name" "$desc"
done

# Step 3: Prompt user to select a build
while true; do
    read -rp "Choose an option (0-$((options - 1))): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 0 && choice < options )); then
        echo "$(echo "$builds" | jq -r ".[$choice].name") selected."
        break
    else
        echo "Invalid choice. Enter a number between 0 and $((options - 1))."
    fi
done
echo -e "\033[0;39;48;2;150;50;50m"
# Step 4: Download
oldpwd="$(pwd)"
iso_url=$root$(echo "$builds" | jq -r ".[$choice].iso_url")
gpg_url=$root$(echo "$builds" | jq -r ".[$choice].gpg_url")
echo "Downloading to $oldpwd/bdj-${distributerName}-$(basename $iso_url)"
tempdir="$(mktemp -d)"
cd $tempdir
if [ $usegpg != "yes" ]; then
    curl $iso_url > "$oldpwd/bdj-${distributerName}-$(basename $iso_url)"
    echo "ISO downloaded"
    echo "NOT CHECKING GPG."
else
    curl $iso_url > bdotj.iso
    echo "ISO downloaded"
    curl $gpg_url > bdotj.iso.gpg
    echo "GPG signature downloaded, checking..."
    gpg --verify bdotj.iso.gpg bdotj.iso
    mv bdotj.iso $oldpwd/bdj-${distributerName}-$(basename $iso_url)
    echo "Moved ISO to target destination"
    echo -e "\033[0;39;49m"
fi
