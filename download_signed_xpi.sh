#!/usr/bin/env bash
#
# Usage: download_signed_xpi.sh -t <token> -i <addon-id> -v <version> -o </path/to/dir>
#
#          -t : JWT token generated by get_token.sh, like: "ABCD..."
#          -i : Addon ID, like: "myaddon@example.com"
#          -v : Version, like: "1.1"
#          -o : Path to output directory
#
#          -k : key aka JWT issuer, like "user:xxxxxx:xxx"
#          -s : JWT secret, like "0123456789abcdef..."
#          -e : seconds to expire the token
#
#          -V : enable debug print
#          -d : dry run
#
# See also: https://blog.mozilla.org/addons/2015/11/20/signing-api-now-available/

tools_dir=$(cd $(dirname $0) && pwd)

case $(uname) in
  Darwin|*BSD|CYGWIN*) sed="sed -E" ;;
  *)                   sed="sed -r" ;;
esac

while getopts t:i:v:o:k:s:e:Vd OPT
do
  case $OPT in
    "t" ) token="$OPTARG" ;;
    "i" ) id="$OPTARG" ;;
    "v" ) version="$OPTARG" ;;
    "o" ) output="$OPTARG" ;;
    "k" ) key="$OPTARG" ;;
    "s" ) secret="$OPTARG" ;;
    "e" ) expire="$OPTARG" ;;
    "V" ) debug=1 ;;
    "d" ) dry_run=1 ;;
  esac
done

if [ "$token" = "" ]
then
  token=$($tools_dir/get_token.sh -k "$key" -s "$secret" -e "$expire")
  [ "$token" = "" ] && exit 1
fi

[ "$token" = "" ] && echo 'You must specify a JWT token via "-t"' 1>&2 && exit 1
[ "$id" = "" ] && echo 'You must specify the addon ID via "-i"' 1>&2 && exit 1
[ "$version" = "" ] && echo 'You must specify the addon ID via "-v"' 1>&2 && exit 1

[ "$output" = "" ] && output=.
output="$(cd "$output" && pwd)"

endpoint="https://addons.mozilla.org/api/v3/addons/$id/versions/$version/"
if [ "$debug" = 1 ]; then echo "endpoint: $endpoint"; fi

response=$(curl $endpoint \
             -s \
             -D - \
             -H "Authorization: JWT $token")

if [ "$debug" = 1 ]; then echo "$response"; fi

if echo "$response" | grep -E '"signed"\s*:\s*true' > /dev/null
then
  uri=$(echo "$response" | \
          grep "download_url" | \
          $sed -e 's/.*"download_url"\s*:\s*"([^"]+).*/\1/')
  file="$output/$id-$version-signed.xpi"
  if [ "$dry_run" != 1 ]
  then
    response=$(curl "$uri" \
                 -g \
                 -s \
                 -L \
                 -D - \
                 -o "$file" \
                 -H "Authorization: JWT $token")
    if [ "$debug" = 1 ]; then echo "$response"; fi
    echo "Signed XPI is downloaded at: $output/$id-$version-signed.xpi"
  else
    echo "Signed XPI will be downloaded at: $output/$id-$version-signed.xpi"
  fi
  exit 0
elif echo "$response" | grep -E 'No uploaded file for that addon and version.' > /dev/null
then
  echo "Version not found." 1>&2
  exit 10
else
  echo "Not signed yet." 1>&2
  exit 1
fi

