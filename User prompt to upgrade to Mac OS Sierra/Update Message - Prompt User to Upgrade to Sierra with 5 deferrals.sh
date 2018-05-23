#!/bin/bash

# Check we have the timer file and if not create it and populate with 5
# which represents the number of defers the end user will have

if [ ! -e /Library/Application\ Support/JAMF/.SierraUpgradeTimer.txt ]; then
    echo "5" > /Library/Application\ Support/JAMF/.SierraUpgradeTimer.txt
fi

########################################################################
#################### Variables to be used by the script ################
########################################################################

# # # # # # # # # # # # # # # #
#Custom Trigger for OS Upgrade
jssOSTrigger="10126_upgrade"
# # # # # # # # # # # # # # # #

#Get the logged in LoggedInUser
LoggedInUser=`python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`
echo "Current LoggedInUser is $LoggedInUser"

# Determine OS version
osvers=$(sw_vers -productVersion | awk -F. '{print $2}')
sw_vers=$(sw_vers -productVersion)

#Get the value of the timer file and store for later
Timer=$(cat /Library/Application\ Support/JAMF/.SierraUpgradeTimer.txt)

##Check if device is on battery or ac power
pwrAdapter=$( /usr/bin/pmset -g ps )
if [[ ${pwrAdapter} == *"AC Power"* ]]; then
	pwrStatus="OK"
	/bin/echo "Power Check: OK - AC Power Detected"
else
	pwrStatus="ERROR"
	/bin/echo "Power Check: ERROR - No AC Power Detected"
fi

##Check if free space > 15GB
osMinor=$( /usr/bin/sw_vers -productVersion | awk -F. {'print $2'} )
if [[ $osMinor -ge 12 ]]; then
	freeSpace=$( /usr/sbin/diskutil info / | grep "Available Space" | awk '{print $4}' )
else
	freeSpace=$( /usr/sbin/diskutil info / | grep "Free Space" | awk '{print $4}' )
fi

if [[ ${freeSpace%.*} -ge 15 ]]; then
	spaceStatus="OK"
	/bin/echo "Disk Check: OK - ${freeSpace%.*}GB Free Space Detected"
else
	spaceStatus="ERROR"
	/bin/echo "Disk Check: ERROR - ${freeSpace%.*}GB Free Space Detected"
fi

#Go get the Sierr icon from Apple's website
curl -s --url https://support.apple.com/library/APPLE/APPLECARE_ALLGEOS/SP742/sierra-roundel-120.png > /var/tmp/sierra-roundel-120.png

jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
icon="/var/tmp/sierra-roundel-120.png"
title="Message from Bauer IT"
heading="An important upgrade is availabe for your Mac - $Timer deferrals remaining"
description="The Mac OS Sierra upgrade includes new features, security updates and performance enhancements.

Would you like to upgrade now? You may choose to not upgrade to Mac OS Sierra now, but after $Timer deferrals your mac will be automatically upgraded.

During this upgrade, you will not have access to your computer! The upgrade can take up to 1 hour to complete.

You must ensure all work is saved before clicking the 'Upgrade Now' button. All of your files and Applications will remain exactly as you leave them.

You can also trigger the upgrade via the Self Service Application at any time e.g. over lunch or just before you leave for the day."

########################################################################
#################### Functions to be used by the script ################
########################################################################

function jamfHelperAsktoUpgrade ()
{
  HELPER=` "$jamfHelper" -windowType utility -icon "$icon" -heading "$heading" -alignHeading center -title "$title" -description "$description" -button1 "Later" -button2 "Upgrade Now" -defaultButton "2" `
}

jamfHelperUpdateInProgress ()
{
#Show a message via Jamf Helper that the update has started - & at end so the script can carry on after jamf helper is launched.
su - $LoggedInUser <<'jamfmsg2'
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /Library/Application\ Support/JAMF/bin/Management\ Action.app/Contents/Resources/Self\ Service.icns -title "Message from Bauer IT" -heading "Downloading Upgrade Package" -alignHeading center -description "Mac OS Sierra upgrade including new features, security updates and performance enhancements has started.

During this upgrade, you will not have access to your computer! The upgrade can take up to 1 hour to complete.

Please...
-Do not turn this Mac off.
-Do not attempt to use this Mac until the login screen is displayed." &
jamfmsg2
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# START THE SCRIPT
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

#First up check is anyone is home, if not then just upgrade
if [ "$LoggedInUser" == "" ]; then
        echo "No one home, upgrade"
        /bin/echo "Call policy to trigger OS upgrade"
        jamf policy -trigger "$jssOSTrigger"
        exit 0
fi


# Check the value of the timer variable, if greater than 0 i.e. can defer
# then show a jamfHelper message
if [ $Timer -gt 0 ]; then
/bin/echo "User has "$Timer" deferrals left"
##Launch jamfHelper
/bin/echo "Launching jamfHelper..."
jamfHelperAsktoUpgrade
#Get the value of the jamfHelper, user chosing to upgrade now or defer.
if [ "$HELPER" == "0" ]; then
        #User chose to ignore
        echo "User clicked no"
        let CurrTimer=$Timer-1
        echo "$CurrTimer" > /Library/Application\ Support/JAMF/.SierraUpgradeTimer.txt
        exit 0
else
        #User clicked yes
        /bin/echo "User clicked yes"
        #Check the Macs meets the space Requirements
        if [[ ${spaceStatus} == "OK" ]]; then
          jamfHelperUpdateInProgress
          /bin/echo "Call policy to trigger OS upgrade"
          jamf policy -trigger "$jssOSTrigger"
        exit 0
        else
        /bin/echo "Launching jamfHelper Dialog (Requirements Not Met)..."
        /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -title "$title" -icon "$icon" -heading "Requirements Not Met" -description "We were unable to prepare your computer for Mac OS Sierra. Please ensure you have at least 15GB of Free Space.

      If you continue to experience this issue, please contact the IT Service Desk" -iconSize 100 -button1 "OK" -defaultButton 1

      exit 1
      fi
fi

fi

# Check the value of the timer variable, if equals 0 then no deferal left run the upgrade

if [ $Timer -eq 0 ]; then
  /bin/echo "No Defer left run the install"
  #Check the Macs meets the power and space Requirements
  if [[ ${pwrStatus} == "OK" ]] && [[ ${spaceStatus} == "OK" ]]; then
    jamfHelperUpdateInProgress
    /bin/echo "Call policy to trigger OS upgrade"
    jamf policy -trigger "$jssOSTrigger"
    exit 0
  else
  /bin/echo "Launching jamfHelper Dialog (Requirements Not Met)..."
  /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -title "$title" -icon "$icon" -heading "Requirements Not Met" -description "We were unable to prepare your computer for Mac OS Sierra. Please ensure you are connected to power and that you have at least 15GB of Free Space.

  If you continue to experience this issue, please contact the IT Service Desk" -iconSize 100 -button1 "OK" -defaultButton 1
  exit 1
  fi
fi
