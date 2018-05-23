# JamfHelper

Scripts that use the jamfHelper binary to engage with users.

## How to use jamfHelper

The Jamf Helper binary /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper can be used to create different types of interactive windows to notify and engage with end users.

sudo /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -help

JAMF Helper Help Page

Usage: jamfHelper -windowType [-windowPostion] [-title] [-heading] [-description] [-icon] [-button1] [-button2] [-defaultButton] [-cancelButton] [-showDelayOptions] [-alignDescription] [-alignHeading] [-alignCountdown] [-timeout] [-countdown] [-iconSize] [-lockHUD] [-startLaunchd] [-fullScreenIcon] [-kill]

-windowType [hud | utility | fs]
	hud: creates an Apple "Heads Up Display" style window
	utility: creates an Apple "Utility" style window
	fs: creates a full screen window the restricts all user input
		WARNING: Remote access must be used to unlock machines in this mode

-windowPosition [ul | ll | ur | lr]
	Positions window in the upper right, upper left, lower right or lower left of the user's screen
	If no input is given, the window defaults to the center of the screen

-title "string"
	Sets the window's title to the specified string

-heading "string"
	Sets the heading of the window to the specified string

-description "string"
	Sets the main contents of the window to the specified string

-icon path
	Sets the windows image filed to the image located at the specified path

-button1 "string"
	Creates a button with the specified label

-button2 "string"
	Creates a second button with the specified label

-defaultButton [1 | 2]
	Sets the default button of the window to the specified button. The Default Button will respond to "return"

-cancelButton [1 | 2]
	Sets the cancel button of the window to the specified button. The Cancel Button will respond to "escape"

-showDelayOptions "int, int, int,..."
	Enables the "Delay Options Mode". The window will display a dropdown with the values passed through the string

-alignDescription [right | left | center | justified | natural]
	Aligns the description to the specified alignment

-alignHeading [right | left | center | justified | natural]
	Aligns the heading to the specified alignment

-alignCountdown [right | left | center | justified | natural]
	Aligns the countdown to the specified alignment

-timeout int
	Causes the window to timeout after the specified amount of seconds
	Note: The timeout will cause the default button, button 1 or button 2 to be selected (in that order)

-countdown
	Displays a string notifying the user when the window will time out

-iconSize pixels
	Changes the image frame to the specified pixel size

-lockHUD
	Removes the ability to exit the HUD by selecting the close button
-startlaunchd
	Starts the JAMF Helper as a launchd process
-kill
	Kills the JAMF Helper when it has been started with launchd
-fullScreenIcon
	Scales the "icon" to the full size of the window
	Note: Only available in full screen mode


Return Values: The JAMF Helper will print the following return values to stdout...
	0 - Button 1 was clicked
	1 - The Jamf Helper was unable to launch
	2 - Button 2 was clicked
	3 - Process was started as a launchd task
	XX1 - Button 1 was clicked with a value of XX seconds selected in the drop-down
	XX2 - Button 2 was clicked with a value of XX seconds selected in the drop-down
	239 - The exit button was clicked
	243 - The window timed-out with no buttons on the screen
	250 - Bad "-windowType"
	255 - No "-windowType"
	



