# Prompting users to upgrade Mac OS

Using the jamfHelper binary to ask users to upgrade their OS with deferrals.

## How to use this script

This script is designed to be used in conjunction with another policy in the JSS. This script is called on the check-in trigger and checks for a logged in user. 

## Scenarios

If no logged in user is found then the policy that does the OS install is called using a custom trigger while at the login window.

If a user is logged in then JamfHelper is called to notifiy the user that an OS upgrade is required and is offered 5 deferrals before the install automatically triggers.
	



