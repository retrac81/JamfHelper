#!/bin/sh

#######################################################################
############### Mac OS update script with JamfPro script variables ####
############### written by Ben Carter February 2018 ###################
#######################################################################

#This script is designed to be used with JamfPro and script variables
#when selecting via a policy

########################################################################
#################### Variables to pulled in from policy ################
########################################################################

PolicyTrigger="$4" #What unique policy trigger actually installs the package
deferralOption1="$5" #deferral time option 1 e.g 0, 300, 3600, 21600 (Now, 5 minutes, 1 hour, 6 hours)
deferralOption2="$6" #deferral time option 2 e.g 0, 300, 3600, 21600 (Now, 5 minutes, 1 hour, 6 hours)
deferralOption3="$7" #deferral time option 3 e.g 0, 300, 3600, 21600 (Now, 5 minutes, 1 hour, 6 hours)
deferralOption4="$8" #deferral time option 4 e.g 0, 300, 3600, 21600 (Now, 5 minutes, 1 hour, 6 hours)
requiredSpace="$9" #In GB how many are requried to compelte the update

########################################################################
#################### Variables to be used by the script ################
########################################################################

#Get the current logged in user and store in variable
LoggedInUser=`python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`
#Get OS version to determine disk space
osvers=$(sw_vers -productVersion | awk -F. '{print $2}')
#Check if the deferral file exists, if not create, if it does read the value and add to a variable
if [ ! -e /Library/Application\ Support/JAMF/.UpdateDefrral-${PolicyTrigger}.txt ]; then
    touch /Library/Application\ Support/JAMF/.UpdateDefrral-${PolicyTrigger}.txt
else
    DeferralTime=$(cat /Library/Application\ Support/JAMF/.UpdateDefrral-${PolicyTrigger}.txt)
    echo "Deferal file present with $DeferralTime Seconds"
fi
########################################################################
#################### Functions to be used by the script ################
########################################################################

#######################################################################################
# This function checks the available space and reports back against $9 from the policy
#######################################################################################
function checkSpace ()
{
#Throws and error and incorrectly reports space available
#  if [[ -z $requiredSpace ]]; then
#      echo "Variable 9 - Space required is empty, setting to 1Gb"
#      requiredSpace="1"
#  fi
  #Check which OS we are running as wording is difrenet from 10.12+
  osMinor=$( /usr/bin/sw_vers -productVersion | awk -F. {'print $2'} )
  if [[ $osMinor -ge 12 ]]; then
  	freeSpace=$( /usr/sbin/diskutil info / | grep "Available Space" | awk '{print $4}' )
  else
  	freeSpace=$( /usr/sbin/diskutil info / | grep "Free Space" | awk '{print $4}' )
  fi
  #Now we have the freespace calulated check if greater than $9 from the policy .
  if [[ ${freeSpace%.*} -ge ${requiredSpace} ]]; then
  	spaceStatus="OK"
  	/bin/echo "Disk Check: OK - ${freeSpace%.*}GB Free Space Detected"
  else
  	spaceStatus="ERROR"
  	/bin/echo "Disk Check: ERROR - ${freeSpace%.*}GB Free Space Detected"
  fi
}

#################################################################################################
# This function asks the user to install updates with deferral options supplied by the policy
################################################################################################

jamfHelperApplyUpdate ()
{
HELPER=$(
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /System/Library/CoreServices/Installer.app/Contents/Resources/Installer.icns -title "Message from Bauer IT" -heading "An important update is waiting to be installed" -alignHeading center -description "The update improves the stability, compatibility, and security of your Mac, and is recommended for all users.

You may choose to install the update now or select one of the deferral times to suit your current workload. After the deferral time lapses the updates will be automatically installed and your Mac will be restarted!

During this update, you will not have access to your Mac. The update can take up to 30 minutes to complete.

You must ensure all work is saved before the update starts!" -lockHUD -showDelayOptions "$deferralOption1, $deferralOption2, $deferralOption3, $deferralOption4"  -button1 "Select"

)
}

########################################################################
# This function advises user that updates ready to install now
########################################################################
jamfHelperUpdateConfirm ()
{
#Show a message via Jamf Helper that the update is ready, this is after it has been deferred
HELPER_CONFIRM=$(
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /System/Library/CoreServices/Installer.app/Contents/Resources/Installer.icns -title "Message from Bauer IT" -heading "    An Important Update is now ready to be installed     " -description "Updates to improve the stability, compatibility, and security are now ready to be installed.

Your Mac will restart once complete!

Please save all of your work before clicking install" -lockHUD -timeout 21600 -button1 "Install" -defaultButton 1
)
}

########################################################################
# This function advises user of the selected defferal
########################################################################
jamfHelperUpdateDeferralConfirm ()
{
#Convert the seconds chosen to human readable days, minutes, hours. No Seconds are calulated
local T=$DeferralTime;
local D=$((T/60/60/24));
local H=$((T/60/60%24));
local M=$((T/60%60));
timeChosenHuman=$(printf '%s' "Updates will be installed in: "; [[ $D > 0 ]] && printf '%d days ' $D; [[ $H > 0 ]] && printf '%d hours ' $H; [[ $M > 0 ]] && printf '%d minutes ' $M; [[ $D > 0 || $H > 0 || $M > 0 ]] )
#Show a message via Jamf Helper that the update is ready, this is after it has been deferred
HELPER_DEFERRAL_CONFIRM=$(
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /Library/Application\ Support/JAMF/bin/Management\ Action.app/Contents/Resources/Self\ Service.icns -title "Message from Bauer IT" -heading "    $timeChosenHuman      " -description "If you would like to install the update sooner please open Self Service and navigate to the updates section." -timeout 10  -button1 "Ok" -defaultButton 1 &
)
}

########################################################################
# This function advises user that updates are installing
########################################################################
jamfHelperUpdateInProgress ()
{
#Show a message via Jamf Helper that the update has started - & at end so the script can carry on after jamf helper is launched.
su - $LoggedInUser <<'jamfmsg2'
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /Library/Application\ Support/JAMF/bin/Management\ Action.app/Contents/Resources/Self\ Service.icns -title "Message from Bauer IT" -heading "    Update in Progress     " -description "Updates to improve the stability, compatibility, and security of your Mac have started.

Your Mac will restart once complete!

Please save all of your work" &
jamfmsg2
}

########################################################################
# This function advises user that the update is complete
########################################################################

function jamfHelperUpdateComplete ()
{
#Show a message via Jamf Helper that the update is complete, only shows for 10 seconds then closes.
su - $LoggedInUser <<'jamfmsg3'
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /Library/Application\ Support/JAMF/bin/Management\ Action.app/Contents/Resources/Self\ Service.icns -title "Message from Bauer IT" -heading "    Update Complete     " -description "Updates have successfully been installed." -button1 "Ok" -defaultButton "1"
jamfmsg3
}

########################################################################
# This function advises user that update failed
########################################################################

function jamfHelperUpdateFailed ()
{
#Show a message via Jamf Helper that the update has Failed.
su - $LoggedInUser <<'jamfmsg4'
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /System/Library/CoreServices/Problem\ Reporter.app/Contents/Resources/ProblemReporter.icns -title "Message from Bauer IT" -heading "    Update Failed    " -description "Updates have failed, please contact the IT Service Desk" -button1 "Ok" -defaultButton "1"
jamfmsg4
}
########################################################################
# This function advises user that update failed due to lack of space
########################################################################
function jamfHelperUpdateFailedSpace ()
{
#Show a message via Jamf Helper that the update has Failed.   
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /System/Library/CoreServices/Problem\ Reporter.app/Contents/Resources/ProblemReporter.icns -title "Message from Bauer IT" -heading "    An important update cannot be installed    " -description "Updates cannot be installed due to insufficient disk space.

${requiredSpace}GB Required
You have ${freeSpace%.*}GB Free.

Please delete old files to make additional space availalble.

If you need asistance with this, please contact the IT Service Desk." -button1 "Ok" -defaultButton "1"

}

function installerWhile ()
{
#While the tmutil porcess is running we wait, this leaves the jamf helper message up. Once restore compelte jamf helper restore in progress message is killed
while ps axg | grep -vw grep | grep -w installer > /dev/null;
do
        echo "Installer running"
        sleep 1;
done
echo "Installer Finished"
killall jamfHelper
}

function performUpdate ()
{

#Call jamf Helper to show message update has started
jamfHelperUpdateInProgress

#Call the policy to run the update
/usr/local/jamf/bin/jamf policy -trigger $PolicyTrigger

#Call while loop to check when the installer process is finished so jamf helper can be killed
installerWhile

#Kill the deferal file after the update has been compelted so this script can be re-used
rm /Library/Application\ Support/JAMF/.UpdateDefrral-${PolicyTrigger}.txt
if [ -e /Library/Application\ Support/JAMF/.UpdateDefrral-${PolicyTrigger}.txt ]; then
    echo "Something went wrong, the deferral timer file is still present"
else
    echo "Deferal file removed as update ran"
fi
}

function addReconOnBoot ()
{
  #Check if recon has already been added to the startup script - the startup script gets overwirtten during a jamf manage.
  if [ ! -z $(grep "/usr/local/jamf/bin/jamf recon" "/Library/Application\ Support/JAMF/ManagementFrameworkScripts/StartupScript.sh") ];
  then
      echo "Rccon already entered in startup script"
  else
      # code if not found
      echo "Recon not found in startup script adding..."
      #Remove the exit from the file
      sed -i '' "/$exit 0/d" /Library/Application\ Support/JAMF/ManagementFrameworkScripts/StartupScript.sh
      #Add in additional recon line with an exit in
      echo /usr/local/jamf/bin/jamf recon >>  /Library/Application\ Support/JAMF/ManagementFrameworkScripts/StartupScript.sh
      echo exit 0 >>  /Library/Application\ Support/JAMF/ManagementFrameworkScripts/StartupScript.sh
      echo "Recon added to startup"
  fi
}
########################################################################
########################################################################
#####################     Start the script      ########################
########################################################################
########################################################################

##########################################
#Check Space Requirements from Supplied $9
checkSpace
##########################################
if [[ ${spaceStatus} == "OK" ]]; then
addReconOnBoot
else
  /bin/echo "Mac did not meet space requirements"
  #Show message to user - no space for update
  jamfHelperUpdateFailedSpace
  exit 1
fi
##########################################
#If Mac meets space requirements then continue
##########################################
if [ "$LoggedInUser" == "" ]; then
    echo "No logged in user, apply update."
    #Call jamf Helper to show message update has started - catches logout trigger
    performUpdate
  else
    #Read the deferral time from the file, incase Mac got rebooted. This will determine the next step
    DeferralTime=$(cat /Library/Application\ Support/JAMF/.UpdateDefrral-${PolicyTrigger}.txt)

    if [[ -z $DeferralTime ]]; then #No Deferral time set so we can now ask the user to set one
      echo "$LoggedInUser will be asked to install $PolicyTrigger with the deferral options $deferralOption1, $deferralOption2, $deferralOption3, $deferralOption4 "
      #Run function to show jamf Helper message to ask user to set deferral time
      jamfHelperApplyUpdate
      #Format the dropdown result from JamfHlper as a 1 gets added at the end when the button is pressed
      timeChosen="${HELPER%?}"
      #Save the selected deferral time to a text file and then add to the variable
      echo "$timeChosen" > /Library/Application\ Support/JAMF/.UpdateDefrral-${PolicyTrigger}.txt
      DeferralTime=$(cat /Library/Application\ Support/JAMF/.UpdateDefrral-${PolicyTrigger}.txt)

      if [ "$HELPER" == "1" ]; then #Option1 is always 0 seconds so no deferral
          echo "$deferralOption1 Selected run it now"
          performUpdate
      else # A deferral time was selected from the dropdown menu, show user what was selected
        jamfHelperUpdateDeferralConfirm #Message auto closes after 10 seconds
        echo "Wait for $DeferralTime before running $PolicyTrigger"
        sleep $DeferralTime
          #Confirm updates are now going to be installed
          jamfHelperUpdateConfirm
          if [ "$HELPER_CONFIRM" == "0" ]; then
            performUpdate
          fi
        fi
    else # A deferral time has already been set and saved in the .UpdateDefrral-${PolicyTrigger}.txt file
      echo " $LoggedInUser already has a deferal time set of $DeferralTime, wait for deferral time then ask to apply update"
      echo "Wait for $DeferralTime before running $PolicyTrigger"
      sleep $DeferralTime
        #Confirm updates are now going to be installed
        jamfHelperUpdateConfirm
        if [ "$HELPER_CONFIRM" == "0" ]; then
          performUpdate
        fi
    fi
fi
