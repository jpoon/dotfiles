#!/bin/bash
# shellcheck disable=SC2154,SC2181
# shellcheck source=/dev/null
#
# A script to automagically update Plex Media Server on Synology NAS
# This must be run as root to natively control running services
#
# Author @michealespinola https://github.com/michealespinola/syno.plexupdate
#
# Original update concept based on: https://github.com/martinorob/plexupdate
#
# Example Synology DSM Scheduled Task type 'user-defined script': 
# bash /volume1/homes/admin/scripts/bash/plex/syno.plexupdate/syno.plexupdate.sh

# SCRAPE SCRIPT PATH INFO
SrceFllPth=$(readlink -f "${BASH_SOURCE[0]}")
SrceFolder=$(dirname "$SrceFllPth")
SrceFileNm=${SrceFllPth##*/}

# REDIRECT STDOUT TO TEE IN ORDER TO DUPLICATE THE OUTPUT TO THE TERMINAL AS WELL AS A .LOG FILE
exec > >(tee "$SrceFllPth.log") 2>"$SrceFllPth.debug"
# ENABLE XTRACE OUTPUT FOR DEBUG FILE
set -x

# SCRIPT VERSION
SpuscrpVer=4.6.9
MinDSMVers=7.0
# PRINT OUR GLORIOUS HEADER BECAUSE WE ARE FULL OF OURSELVES
printf "\n"
printf "%s\n" "SYNO.PLEX UPDATE SCRIPT v$SpuscrpVer for DSM 7"
printf "\n"

# CHECK IF ROOT
if [ "$EUID" -ne "0" ]; then
  printf ' %s\n' "* This script MUST be run as root - exiting.."
  /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task failed. Script was not run as root."}'
  printf "\n"
  exit 1
fi

# CHECK IF DEFAULT CONFIG FILE EXISTS, IF NOT CREATE IT
create_or_update_config() {
  local ConfigFile="$1"
  if [ ! -f "$ConfigFile" ]; then
    printf '%s\n\n' "* CONFIGURATION FILE (config.ini) IS MISSING, CREATING DEFAULT SETUP.."
    touch "$ConfigFile"
    ExitStatus=1
  fi
  # Function to add key-value pairs along with comments if not present
  add_config_with_comment() {
    local key="$1"
    local value="$2"
    local comment="$3"
    if ! grep -q "^$key=" "$ConfigFile"; then
      printf '%s\n' "$comment" >> "$ConfigFile"
      printf '%s\n' "$key=$value" >> "$ConfigFile"
    fi
  }
  # Default configurations
  add_config_with_comment "MinimumAge" "7"   "# A NEW UPDATE MUST BE THIS MANY DAYS OLD"
  add_config_with_comment "OldUpdates" "60"  "# PREVIOUSLY DOWNLOADED PACKAGES DELETED IF OLDER THAN THIS MANY DAYS"
  add_config_with_comment "NetTimeout" "900" "# NETWORK TIMEOUT IN SECONDS (900s = 15m)"
  add_config_with_comment "SelfUpdate" "0"   "# SCRIPT WILL SELF-UPDATE IF SET TO 1"
}
create_or_update_config "$SrceFolder/config.ini"

# LOAD CONFIG FILE IF IT EXISTS
if [ -f "$SrceFolder/config.ini" ]; then
  source "$SrceFolder/config.ini"
fi

# PRINT SCRIPT STATUS/DEBUG INFO
printf '%16s %s\n'                   "Script:" "$SrceFileNm"
printf '%16s %s\n'               "Script Dir:" "$(fold -w 72 -s     < <(printf '%s' "$SrceFolder") | sed '2,$s/^/                 /')"

# OVERRIDE SETTINGS WITH CLI OPTIONS
while getopts ":a:c:mh" opt; do
  case ${opt} in
    a) # AUTO-UPDATE SCRIPT AND PLEX
      # Check if the value is numerical only
      if [[ $OPTARG =~ ^[0-9]+$ ]]; then
        MinimumAge=$OPTARG
        printf '%16s %s\n'         "Override:" "-a, Minimum Age set to $MinimumAge days"
      else
        printf '\n%16s %s\n\n'   "Bad Option:" "-a, requires a number value for minimum age in days"
        exit 1
      fi
      ;;
    c) # CHOOSE UPDATE CHANNEL
      case $OPTARG in
        p) UpdtChannl="0" # Public channel
          printf '%16s %s\n'       "Override:" "-c, Update Channel set to Public"
          ;;
        b) UpdtChannl="8" # Beta channel
          printf '%16s %s\n'       "Override:" "-c, Update Channel set to Beta"
          ;;
        *)
          printf '\n%16s %s\n\n' "Bad Option:" "-c, Requires either 'p' for Public or 'b' for Beta channels"
          exit 1
          ;;
      esac
      ;;
    m) # UPDATE TO MASTER BRANCH (NON-RELEASE)
      MasterUpdt=true
      printf '%16s %s\n'           "Override:" "-m, Forcing script update from Master branch"
      ;;
    h) # HELP OPTION
      printf '\n%s\n\n'  "Usage: $SrceFileNm [-a #] [-c p|b] [-m] [-h]"
      printf ' %s\n'   "-a: Override the minimum age in days"
      printf ' %s\n'   "-c: Override the update channel (p for Public, b for Beta)"
      printf ' %s\n'   "-m: Update from the master branch (non-release version)"
      printf ' %s\n\n' "-h: Display this help message"
      exit 0
      ;;
    \?) # INVALID OPTION
      printf '\n%16s %s\n\n'     "Bad Option:" "-$OPTARG, Invalid"
      exit 1
      ;;
    :) # MISSING ARGUMENT
      printf '\n%16s %s\n\n'     "Bad Option:" "-$OPTARG, Requires an argument"
      exit 1
      ;;
  esac
done

# CHECK IF SCRIPT IS ARCHIVED
if [ ! -d "$SrceFolder/Archive/Scripts" ]; then
  mkdir -p "$SrceFolder/Archive/Scripts"
fi
if [ ! -f "$SrceFolder/Archive/Scripts/syno.plexupdate.v$SpuscrpVer.sh" ]; then
  cp "$SrceFllPth" "$SrceFolder/Archive/Scripts/syno.plexupdate.v$SpuscrpVer.sh"
else
  cmp -s "$SrceFllPth" "$SrceFolder/Archive/Scripts/syno.plexupdate.v$SpuscrpVer.sh"
  if [ "$?" -ne "0" ]; then
    cp "$SrceFllPth" "$SrceFolder/Archive/Scripts/syno.plexupdate.v$SpuscrpVer.sh"
  fi
fi

# GET EPOCH TIMESTAMP FOR AGE CHECKS
TodaysDate=$(date +%s)

# SCRAPE GITHUB WEBSITE FOR LATEST INFO
GitHubRepo=michealespinola/syno.plexupdate
GitHubHtml=$(curl -i -m "$NetTimeout" -Ls https://api.github.com/repos/$GitHubRepo/releases?per_page=1)
if [ "$?" -eq "0" ]; then
  # AVOID SCRAPING SQUARED BRACKETS BECAUSE GITHUB IS INCONSISTENT
  GitHubJson=$(grep -oPz '\{\s{0,6}\"\X*\s{0,4}\}'          < <(printf '%s' "$GitHubHtml") | tr -d '\0')
  # ADD SQUARED BRACKETS BECAUSE ITS PROPER AND JQ NEEDS IT
  GitHubJson=$'[\n'"$GitHubJson"$'\n]'
  GitHubHtml=$(grep -oPz '\X*\{\W{0,6}\"'                   < <(printf '%s' "$GitHubHtml")  | tr -d '\0' | sed -z 's/\W\[.*//')
  # SCRAPE CURRENT RATE LIMIT
  SpusApiRlm=$(grep -oP '^x-ratelimit-limit: \K[\d]+'       < <(printf '%s' "$GitHubHtml"))
  SpusApiRlr=$(grep -oP '^x-ratelimit-remaining: \K[\d]+'   < <(printf '%s' "$GitHubHtml"))
  #if [[ -n "$SpusApiRlm" && -n "$SpusApiRlr" ]]; then
  #  SpusApiRla=$((SpusApiRlm - SpusApiRlr))
  #fi
  # SCRAPE API MESSAGES
  SpusApiMsg=$(jq -r '.[].message'                          < <(printf '%s' "$GitHubJson"))
  SpusApiDoc=$(jq -r '.[].documentation_url'                < <(printf '%s' "$GitHubJson"))
  # SCRAPE EXPECTED RELEASE-RELATED INFO
  SpusNewVer=$(jq -r '.[].tag_name'                         < <(printf '%s' "$GitHubJson"))
  SpusNewVer=${SpusNewVer#v}
  SpusRlDate=$(jq -r '.[].published_at'                     < <(printf '%s' "$GitHubJson"))
  SpusRlDate=$(date --date "$SpusRlDate" +'%s')
  SpusRelAge=$(((TodaysDate-SpusRlDate)/86400))
  if [ "$MasterUpdt" = "true" ]; then
    SpusDwnUrl=https://raw.githubusercontent.com/$GitHubRepo/master/syno.plexupdate.sh
    SpusRelDes=$'* Check GitHub for master branch commit messages and extended descriptions'
  else
    SpusDwnUrl=https://raw.githubusercontent.com/$GitHubRepo/v$SpusNewVer/syno.plexupdate.sh
    SpusRelDes=$(jq -r '.[].body'                             < <(printf '%s' "$GitHubJson"))
  fi
  SpusHlpUrl=https://github.com/$GitHubRepo/issues
else
  printf ' %s\n\n' "* UNABLE TO CHECK FOR LATEST VERSION OF SCRIPT.."
  ExitStatus=1
fi

# PRINT SCRIPT STATUS/DEBUG INFO
#printf '%16s %s\n'           "Script:" "$SrceFileNm"
#printf '%16s %s\n'       "Script Dir:" "$(fold -w 72 -s     < <(printf '%s' "$SrceFolder") | sed '2,$s/^/                 /')"
printf '%16s %s\n'      "Running Ver:" "$SpuscrpVer"

if [ "$SpusNewVer" = "null" ]; then
  printf "%16s %s\n" "GitHub API Msg:" "$(fold -w 72 -s     < <(printf '%s' "$SpusApiMsg") | sed '2,$s/^/                 /')"
  printf "%16s %s\n" "GitHub API Lmt:" "$SpusApiRlm connections per hour per IP"
  printf "%16s %s\n" "GitHub API Doc:" "$(fold -w 72 -s     < <(printf '%s' "$SpusApiDoc") | sed '2,$s/^/                 /')"
  ExitStatus=1
elif [ "$SpusNewVer" != "" ]; then
  printf '%16s %s\n'     "Online Ver:" "$SpusNewVer (attempts left $SpusApiRlr/$SpusApiRlm)"
  printf '%16s %s\n'       "Released:" "$(date --rfc-3339 seconds --date @"$SpusRlDate") ($SpusRelAge+ days old)"
fi

# COMPARE SCRIPT VERSIONS
if [[ "$SpusNewVer" != "null" ]]; then
  if /usr/bin/dpkg --compare-versions "$SpusNewVer" gt "$SpuscrpVer" || [[ "$MasterUpdt" == "true" ]]; then
    if [[ "$MasterUpdt" == "true" ]]; then
      printf '%17s%s\n' '' "* Updating from master branch!"
    else
      printf '%17s%s\n' '' "* Newer version found!"
    fi
    # DOWNLOAD AND INSTALL THE SCRIPT UPDATE
    if [ "$SelfUpdate" -eq "1" ]; then
      if [ "$SpusRelAge" -ge "$MinimumAge" ] || [ "$MasterUpdt" = "true" ]; then
        printf "\n"
        printf "%s\n" "INSTALLING NEW SCRIPT:"
        printf "%s\n" "----------------------------------------"
        /bin/wget -nv -O "$SrceFolder/Archive/Scripts/$SrceFileNm" "$SpusDwnUrl"                               2>&1
        if [ "$?" -eq "0" ]; then
          # MAKE A COPY FOR UPGRADE COMPARISON BECAUSE WE ARE GOING TO MOVE NOT COPY THE NEW FILE
          cp -f -v "$SrceFolder/Archive/Scripts/$SrceFileNm"     "$SrceFolder/Archive/Scripts/$SrceFileNm.cmp" 2>&1
          # MOVE-OVERWRITE INSTEAD OF COPY-OVERWRITE TO NOT CORRUPT RUNNING IN-MEMORY VERSION OF SCRIPT
          mv -f -v "$SrceFolder/Archive/Scripts/$SrceFileNm"     "$SrceFolder/$SrceFileNm"                     2>&1
          printf "%s\n" "----------------------------------------"
          cmp -s   "$SrceFolder/Archive/Scripts/$SrceFileNm.cmp" "$SrceFolder/$SrceFileNm"
          if [ "$?" -eq "0" ]; then
            printf '%17s%s\n' '' "* Script update succeeded!"
            /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Syno.Plex Update\n\nSelf-Update completed successfully"}'
            ExitStatus=1
            if [ -n "$SpusRelDes" ]; then
              # SHOW RELEASE NOTES
              printf "\n"
              printf "%s\n" "RELEASE NOTES:"
              printf "%s\n" "----------------------------------------"
              printf "%s\n" "$SpusRelDes"
              printf "%s\n" "----------------------------------------"
              printf "%s\n" "Report issues to: $SpusHlpUrl"
            fi
          else
            printf '%17s%s\n' '' "* Script update failed to overwrite."
            /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Syno.Plex Update\n\nSelf-Update failed."}'
            ExitStatus=1
          fi
        else
          printf '%17s%s\n' '' "* Script update failed to download."
          /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Syno.Plex Update\n\nSelf-Update failed to download."}'
          ExitStatus=1
        fi
      else
        printf ' \n%s\n' "Update newer than $MinimumAge days - skipping.."
      fi
      # DELETE TEMP COMPARISON FILE
      find "$SrceFolder/Archive/Scripts" -type f -name "$SrceFileNm.cmp" -delete
    fi
  
  else
    printf '%17s%s\n' '' "* No new version found."
  fi
fi
printf "\n"

# SCRAPE SYNOLOGY HARDWARE MODEL
SynoHModel=$(< /proc/sys/kernel/syno_hw_version)
# SCRAPE SYNOLOGY CPU ARCHITECTURE FAMILY
ArchFamily=$(uname --machine)

# FIXES FOR INCONSISTENT ARCHITECTURE MATCHES
[ "$ArchFamily" = "i686" ]   && ArchFamily=x86
[ "$ArchFamily" = "armv7l" ] && ArchFamily=armv7neon

# SCRAPE DSM VERSION AND CHECK COMPATIBILITY
DSMVersion=$(grep -i "productversion=" "/etc.defaults/VERSION" | cut -d"\"" -f 2)
if /usr/bin/dpkg   --compare-versions "$DSMVersion" "ge" "5.2"   && /usr/bin/dpkg --compare-versions "$DSMVersion" "lt" "7"; then
  DSMplexNID="synology"
elif /usr/bin/dpkg --compare-versions "$DSMVersion" "ge" "7"     && /usr/bin/dpkg --compare-versions "$DSMVersion" "lt" "7.2.2"; then
  DSMplexNID="synology-dsm7"
elif /usr/bin/dpkg --compare-versions "$DSMVersion" "ge" "7.2.2" && /usr/bin/dpkg --compare-versions "$DSMVersion" "lt" "8"; then
  DSMplexNID="synology-dsm72"
else
  printf ' %s\n' "* Unsupported DSM version: $DSMVersion - exiting.."
  /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task failed. No coinciding Plex version identified for this version of Synology DSM."}'
  printf "\n"
  exit 1
fi

# CHECK IF DSM 7
if /usr/bin/dpkg --compare-versions "$MinDSMVers" gt "$DSMVersion"; then
  printf ' %s\n' "* Syno.Plex Update requires DSM $MinDSMVers minimum to install - exiting.."
  /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task failed. DSM not sufficient version."}'
  printf "\n"
  exit 1
fi
DSMVersion=$(grep -i "buildnumber="    "/etc.defaults/VERSION" | cut -d'"' -f 2 | { read -r build; printf '%s-%s' "$DSMVersion" "$build"; })
DSMUpdateV=$(grep -i "smallfixnumber=" "/etc.defaults/VERSION" | cut -d'"' -f 2)
if [ -n "$DSMUpdateV" ]; then
  DSMVersion="$DSMVersion Update $DSMUpdateV"
fi

# SCRAPE CURRENTLY RUNNING PMS VERSION
RunVersion=$(/usr/syno/bin/synopkg version "PlexMediaServer")
RunVersion=$(grep -oP '^.+?(?=\-)'                          < <(printf '%s' "$RunVersion"))

# SCRAPE PMS FOLDER LOCATION AND CREATE ARCHIVED PACKAGES DIR W/OLD FILE CLEANUP
PlexFolder=$(readlink /var/packages/PlexMediaServer/shares/PlexMediaServer)
PlexFolder="$PlexFolder/AppData/Plex Media Server"

if [ -d "$PlexFolder/Updates" ]; then
  mv -f "$PlexFolder/Updates/"* "$SrceFolder/Archive/Packages/" 2>/dev/null
  if [ -n "$(find "$PlexFolder/Updates/" -prune -empty 2>/dev/null)" ]; then
    rmdir "$PlexFolder/Updates/"
  fi
fi
if [ -d "$SrceFolder/Archive/Packages" ]; then
  find "$SrceFolder/Archive/Packages" -type f -name "PlexMediaServer*.spk" -mtime +"$OldUpdates" -delete
else
  mkdir -p "$SrceFolder/Archive/Packages"
fi

# SCRAPE PLEX ONLINE TOKEN
PlexOToken=$(grep -oP "PlexOnlineToken=\"\K[^\"]+"     "$PlexFolder/Preferences.xml")
# SCRAPE PLEX SERVER UPDATE CHANNEL
PlexChannl=$(grep -oP "ButlerUpdateChannel=\"\K[^\"]+" "$PlexFolder/Preferences.xml")
[ -n "$UpdtChannl" ] && PlexChannl="$UpdtChannl" # Override with command line option
if [ -z "$PlexChannl" ]; then
  # DEFAULT TO PUBLIC SERVER UPDATE CHANNEL IF NULL (NEVER SET) VALUE
  ChannlName=Public
  ChannelUrl="https://plex.tv/api/downloads/5.json"
else
  if [ "$PlexChannl" -eq "0" ]; then
    # PUBLIC SERVER UPDATE CHANNEL
    ChannlName=Public
    ChannelUrl="https://plex.tv/api/downloads/5.json"
  elif [ "$PlexChannl" -eq "8" ]; then
    # BETA SERVER UPDATE CHANNEL (REQUIRES PLEX PASS)
    ChannlName=Beta
    ChannelUrl="https://plex.tv/api/downloads/5.json?channel=plexpass&X-Plex-Token=$PlexOToken"
  else
    # REPORT ERROR IF UNRECOGNIZED CHANNEL SELECTION
    printf ' %s\n' "Unable to identify Server Update Channel (Public, Beta, etc) - exiting.."
    /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task failed. Could not identify update channel (Public, Beta, etc)."}'
    printf "\n"
    exit 1
  fi
fi

# SCRAPE PLEX WEBSITE FOR UPDATE INFO
PlexTvHtml=$(curl -i -m "$NetTimeout" -Ls "$ChannelUrl")
if [ "$?" -eq "0" ]; then
  # AVOID SCRAPING SQUARED BRACKETS BECAUSE GITHUB IS INCONSISTENT
  PlexTvJson=$(grep -oPz '\{\s{0,6}\"\X*\s{0,4}\}'          < <(printf '%s' "$PlexTvHtml") | tr -d '\0')
  # ADD SQUARED BRACKETS BECAUSE ITS PROPER AND JQ NEEDS IT
  PlexTvJson=$'[\n'"$PlexTvJson"$'\n]'
  #PlexTvHtml=$(grep -oPz '\X*\{\W{0,6}\"'                   < <(printf '%s' "$PlexTvHtml")  | tr -d '\0' | sed -z 's/\W\[.*//')
  NewVerFull=$(jq --arg DSMplexNID "$DSMplexNID"                                -r '.[].nas[] | select(.id == $DSMplexNID) | .version'      < <(printf '%s' "$PlexTvJson"))
  NewVersion=$(grep -oP '^.+?(?=\-)'                                                                                                        < <(printf '%s' "$NewVerFull"))
  NewVerDate=$(jq --arg DSMplexNID "$DSMplexNID"                                -r '.[].nas[] | select(.id == $DSMplexNID) | .release_date' < <(printf '%s' "$PlexTvJson"))
  NewVerAddd=$(jq --arg DSMplexNID "$DSMplexNID"                                -r '.[].nas[] | select(.id == $DSMplexNID) | .items_added'  < <(printf '%s' "$PlexTvJson"))
  NewVerFixd=$(jq --arg DSMplexNID "$DSMplexNID"                                -r '.[].nas[] | select(.id == $DSMplexNID) | .items_fixed'  < <(printf '%s' "$PlexTvJson"))
  NewDwnlUrl=$(jq --arg DSMplexNID "$DSMplexNID" --arg ArchFamily "$ArchFamily" -r '.[].nas[] | select(.id == $DSMplexNID) | .releases[] | select(.build == "linux-"+$ArchFamily) | .url' < <(printf '%s' "$PlexTvJson"))
  NewPackage="${NewDwnlUrl##*/}"
  # CALCULATE NEW PACKAGE AGE FROM RELEASE DATE
  PackageAge=$(((TodaysDate-NewVerDate)/86400))
else
  printf ' %s\n' "* UNABLE TO CHECK FOR LATEST VERSION OF PLEX MEDIA SERVER.."
  printf "\n"
  ExitStatus=1
fi

# UPDATE LOCAL VERSION CHANGELOG
grep -q           "Version $NewVersion ($(date --rfc-3339 seconds --date @"$NewVerDate"))"    "$SrceFolder/Archive/Packages/changelog.txt" 2>/dev/null
if [ "$?" -ne "0" ]; then
  {
    printf "%s\n" "Version $NewVersion ($(date --rfc-3339 seconds --date @"$NewVerDate"))"
    printf "%s\n" "$ChannlName Channel"
    printf "%s\n" ""
    printf "%s\n" "New Features:"
    printf "%s\n" "$NewVerAddd" | awk '{ print "* " $BASH_SOURCE }'
    printf "%s\n" ""
    printf "%s\n" "Fixed Features:"
    printf "%s\n" "$NewVerFixd" | awk '{ print "* " $BASH_SOURCE }'
    printf "%s\n" ""
    printf "%s\n" "----------------------------------------"
    printf "%s\n" ""
  } >> "$SrceFolder/Archive/Packages/changelog.new"
  if [ -f "$SrceFolder/Archive/Packages/changelog.new" ]; then
    if [ -f "$SrceFolder/Archive/Packages/changelog.txt" ]; then
      mv    "$SrceFolder/Archive/Packages/changelog.txt" "$SrceFolder/Archive/Packages/changelog.tmp"
      cat   "$SrceFolder/Archive/Packages/changelog.new" "$SrceFolder/Archive/Packages/changelog.tmp" > "$SrceFolder/Archive/Packages/changelog.txt"
    else
      mv    "$SrceFolder/Archive/Packages/changelog.new" "$SrceFolder/Archive/Packages/changelog.txt"    
    fi
  fi
fi
rm "$SrceFolder/Archive/Packages/changelog.new" "$SrceFolder/Archive/Packages/changelog.tmp" 2>/dev/null

# PRINT PLEX STATUS/DEBUG INFO
printf '%16s %s\n'         "Synology:" "$SynoHModel ($ArchFamily), DSM $DSMVersion"
printf '%16s %s\n'         "Plex Dir:" "$(fold -w 72 -s     < <(printf '%s' "$PlexFolder") | sed '2,$s/^/                 /')"
printf '%16s %s\n'      "Running Ver:" "$RunVersion"
if [ "$NewVersion" != "" ]; then
  printf '%16s %s\n'     "Online Ver:" "$NewVersion ($ChannlName Channel for $DSMplexNID)"
  printf '%16s %s\n'       "Released:" "$(date --rfc-3339 seconds --date @"$NewVerDate") ($PackageAge+ days old)"
else
  printf '%16s %s\n'     "Online Ver:" "Nonexistent ($ChannlName Channel for $DSMplexNID)"
  ExitStatus=1
fi

# COMPARE PLEX VERSIONS
if /usr/bin/dpkg --compare-versions "$NewVersion" gt "$RunVersion"; then
  printf '%17s%s\n' '' "* Newer version found!"
  printf "\n"
  printf '%16s %s\n'    "New Package:" "$NewPackage"
  printf '%16s %s\n'    "Package Age:" "$PackageAge+ days old ($MinimumAge+ required for install)"
  printf "\n"

  # DOWNLOAD AND INSTALL THE PLEX UPDATE
  if [ "$PackageAge" -ge "$MinimumAge" ]; then
    printf "%s\n" "INSTALLING NEW PACKAGE:"
    printf "%s\n" "----------------------------------------"
    printf "%s\n" "Downloading PlexMediaServer package:"
    if [ -f "$SrceFolder/Archive/Packages/$NewPackage" ]; then
      printf "%s\n" "* Package already exists in local Archive"
    fi
    /bin/wget -nv -c -nc -P "$SrceFolder/Archive/Packages/" "$NewDwnlUrl"                                      2>&1
    if [ "$?" -eq "0" ]; then
      printf "\n%s\n"   "Stopping PlexMediaServer service:"
      /usr/syno/bin/synopkg stop    "PlexMediaServer"
      printf "\n%s\n" "Installing PlexMediaServer update:"
      # INSTALL WHILE STRIPPING OUTPUT ANNOYANCES 
      /usr/syno/bin/synopkg install "$SrceFolder/Archive/Packages/$NewPackage" | awk '{gsub("<[^>]*>", "")}1' | awk '{gsub(/\\nNote:.*?\\n",/, RS)}1'
      printf "\n%s\n" "Starting PlexMediaServer service:"
      /usr/syno/bin/synopkg start   "PlexMediaServer"
    else
      printf '\n %s\n' "* Package download failed, skipping install.."
    fi
    printf "%s\n" "----------------------------------------"
    printf "\n"
    NowVersion=$(/usr/syno/bin/synopkg version "PlexMediaServer")
    printf '%16s %s\n'  "Update from:" "$RunVersion"
    printf '%16s %s'             "to:" "$NewVersion"

    # REPORT PLEX UPDATE STATUS
    if /usr/bin/dpkg --compare-versions "$NowVersion" gt "$RunVersion"; then
      printf ' %s\n' "succeeded!"
      printf "\n"
      if [ -n "$NewVerAddd" ]; then
        # SHOW NEW PLEX FEATURES
        printf "%s\n" "NEW FEATURES:"
        printf "%s\n" "----------------------------------------"
        printf "%s\n" "$NewVerAddd" | awk '{ print "* " $BASH_SOURCE }'
        printf "%s\n" "----------------------------------------"
      fi
      printf "\n"
      if [ -n "$NewVerFixd" ]; then
        # SHOW FIXED PLEX FEATURES
        printf "%s\n" "FIXED FEATURES:"
        printf "%s\n" "----------------------------------------"
        printf "%s\n" "$NewVerFixd" | awk '{ print "* " $BASH_SOURCE }'
        printf "%s\n" "----------------------------------------"
      fi
      /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task completed successfully"}'
      ExitStatus=1
    else
      printf ' %s\n' "failed!"
      /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task failed. Installation not newer version."}'
      ExitStatus=1
    fi
  else
    printf ' %s\n' "Update newer than $MinimumAge days - skipping.."
  fi
else
  printf '%17s%s\n' '' "* No new version found."
fi

printf "\n"

# CLOSE AND NORMALIZE THE LOGGING REDIRECTIONS
exec >&- 2>&- 1>&2

# EXIT NORMALLY BUT POSSIBLY WITH FORCED EXIT STATUS FOR SCRIPT NOTIFICATIONS
if [ -n "$ExitStatus" ]; then
  exit "$ExitStatus"
fi