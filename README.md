CalDav-Web-Client
=================

CalDav Web Client is an open source web client to view calendar entries of CalDav servers.

### Requirements

 * installed CalDav server (e.g. Baïkal or ownCloud)
 * HTML5 compatible webbrowser (e.g. firefox, chrome or IE9+) for localstorage

### Installation

 1. clone this repository to the same domain where your caldav server runs
 2. open index.html in your webbrowser and set credentials
 3. view your calendar entries

### Features

 * authentication against CalDav server using an ajax request
 * fetch calendar entries by month, week and day
 * display calendar entries

### Compatibility
This application is developed against the open source CalDav server Baïkal (https://github.com/jeromeschneider/Baikal/)
which uses the popular sabre/dav library (http://sabre.io/dav/caldav/).
As far as i know ownCloud is also based on sabre/dav, so this application should be 
compatible to the ownCloud CalDAV server, too.

### How does it work?
After entering your credentials the application fires a REPORT HTTP request against the CalDav server url you specified.
It uses the time-range filter of the CalDav standard.
The application itself is developed using jQuery, jQuery FullCalendar, CoffeeScript and LessCSS.

### Planned features

 * using the HTML5 Notification API to notify the user about an appointment by evaluating the defined reminder of an appointment
 * perhaps implement a simple edit form to create and update an appointment (low prio)
