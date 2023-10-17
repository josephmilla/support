#!/bin/zsh
###################################################################################################
# Created by Noah Anderson | se@kandji.io | Kandji, Inc. | Systems Engineering
# Modified by Sean Burke | se@kandji.io | Kandji, Inc. | Systems Engineering
###################################################################################################
# Created on 05/18/2022
# Updated on 10/16/2023
###################################################################################################
# Software Information
###################################################################################################
#
# Version 1.0.0
#
# Uninstaller script for Microsoft Teams (Classic)
# NOTE: It is recommended you remove Microsoft Teams (Classic) from any Blueprints where this uninstaller is added
# NOTE: Failure to do so may result in Microsoft Teams (Classic) being reinstalled upon next Kandji agent check-in
# Code will first kill any active Microsoft Teams (Classic) processes
# Next, if Microsoft Teams (Classic) application bundle exists in /Applications, it will be deleted
# Finally, iterates over all users with UID ≥ 500, populates their home directory paths,
# and confirms a user Library exists under the identified home directory by NFSHomeDirectory
# For users with valid user libraries, searches multiple paths for Microsoft Teams (Classic) pref folders/files
# If any are matched, they will be logged to stdout via echo and then recursively removed via rm
#
###################################################################################################
# License Information
###################################################################################################
# Copyright 2023 Kandji, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
# to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
# FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
###################################################################################################

###################################################################################################
########################################## DO NOT MODIFY ##########################################
###################################################################################################

##############################
########## VARIABLES #########
##############################

application_path="/Applications/Microsoft Teams classic.app"
application_path_secondary="/Applications/Microsoft Teams.app"
app_friendly_name="Microsoft Teams (Classic)"

###############
##### BODY ####
###############

# Populate array of users from DSCL with UID ≥500
dscl_users=($(/usr/bin/dscl /Local/Default -list /Users UniqueID | /usr/bin/awk '$2 >= 500 {print $1}'))

if [[ -e "${application_path}" || -e "${application_path_secondary}" ]]; then

    # Kill App Processes
    /bin/echo "Killing any active ${app_friendly_name} processes..."
    /bin/ps aux | /usr/bin/grep -i 'Microsoft Teams classic.app\|Microsoft Teams.app' | /usr/bin/grep -v grep | /usr/bin/awk '{print $2}' | /usr/bin/xargs kill -9

    /bin/echo "Deleting application bundle for ${app_friendly_name}..."
    /bin/rm -f -R "${application_path}"
    /bin/rm -f -R "${application_path_secondary}"

    for du in "${dscl_users[@]}"; do
        # Derive home directory value from DSCL attribute
        user_dir=$(/usr/bin/dscl /Local/Default -read "/Users/${du}" NFSHomeDirectory | /usr/bin/cut -d ":" -f2 | /usr/bin/xargs)

        # Confirm User Library dir exists
        if [[ -d "${user_dir}/Library" ]]; then
            /bin/echo "Valid user directory for ${du} at ${user_dir}"

            launchds=(
                "/Library/LaunchDaemons/com.microsoft.teams.TeamsUpdaterDaemon.plist"
            )

            app_dirs=(
                "${user_dir}/Library/Application Support/Microsoft/Teams"
                "${user_dir}/Library/Application Support/com.microsoft.teams"
                "${user_dir}/Library/Application Support/Teams"
                "${user_dir}/Library/Saved Application State/com.microsoft.teams.savedState"
                "${user_dir}/Library/Preferences/com.microsoft.teams.plist"
                "${user_dir}/Library/Logs/Microsoft Teams"
                "${user_dir}/Library/HTTPStorages/com.microsoft.teams"
                "${user_dir}/Library/HTTPStorages/com.microsoft.teams.binarycookies"
                "${user_dir}/Library/WebKit/com.microsoft.teams"
                "${user_dir}/Library/Logs/Microsoft Teams classic Helper (Renderer)"
                "${user_dir}/Library/Caches/com.microsoft.teams"
                "/Library/Preferences/com.microsoft.teams.plist"
                "/Library/Audio/Plug-Ins/HAL/MSTeamsAudioDevice.driver"
                "/Library/Logs/Microsoft/Teams"
            )

            # Iterate over array of the above LaunchDaemons
            # If any are found, print match to stdout then unload and remove
            for launchd in "${launchds[@]}"; do
                if [[ -f "${launchd}" ]]; then
                    /bin/echo "Unloading and removing ${launchd}..."
                    /bin/launchctl unload "${launchd}" 2>/dev/null
                    /bin/rm -f "${launchd}" 2>/dev/null
                fi
            done

            # Iterate over array of the above user directories
            # If any paths are found, print match to stdout and delete them
            for dir in "${app_dirs[@]}"; do
                if [[ -e "${dir}" ]]; then
                    /bin/echo "Removing ${dir}..."
                    /bin/rm -f -R "${dir}" 2>/dev/null
                fi
            done
        fi
    done
    exit 0
else
    /bin/echo "${app_friendly_name} not found, exiting."
    exit 0
fi