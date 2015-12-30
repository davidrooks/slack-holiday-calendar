#USAGE

Start up using ruby app.rb

Optional environment variables:

    * USER - a comma seperated list of users who can send the /timesheets command to prevent misuse
    * SEND_TO - if send_to = ALL then send response to everyone in the channel, else only send to self (for testing)
    
Create a new slack command in slack for /timesheet and point it to this app

#EXPLANATION

This is a very simple API for a slack integration. 

If no users are passed with the command (e.g. /timesheets) then it just sends out a channel wide reminder to everyone to complete their timesheets
If users are passed with command (e.g. /timesheets @user) then it...

1. increments the number of times that a @user has been late with their timesheet
1. notifies @user that they need to complete their timesheet
1. if @user has been late too many times then deals out a punishment
