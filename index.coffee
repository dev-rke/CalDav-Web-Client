class Calendar
  constructor: (@caldav) ->
    @calendar = jQuery('#calendar')
    @calendar.fullCalendar
      agenda: 'h:mm{ - h:mm}'
      firstDay: 1
      header:
        left: 'prev,next today'
        center: 'title'
        right: 'month,agendaWeek,agendaDay'
    @calendar.fullCalendar 'addEventSource', (viewStartDate, viewEndDate)=>
      @caldav.get(@addCalendarEntry, @convertDateToIcalTime(viewStartDate), @convertDateToIcalTime(viewEndDate))

  addCalendarEntry: (calDavEntry) =>
    if calDavEntry?.VEVENT?
      if calDavEntry.VEVENT.DTEND
        end = @convertICalTimeToISOTime(calDavEntry.VEVENT.DTEND)
      event = {
        id: calDavEntry.VEVENT.UID
        title: calDavEntry.VEVENT.SUMMARY
        start: @convertICalTimeToISOTime(calDavEntry.VEVENT.DTSTART)
        end: end
      }
      @calendar.fullCalendar('renderEvent', event)

  convertICalTimeToISOTime: (time) =>
    matches = time.match(/(\d{4})(\d{2})(\d{2})T?(\d{2})?(\d{2})?(\d{2})?(Z?)/i)
    matches.shift()
    day = matches.slice(0, 3).join('-')
    time = matches.slice(3,6).join(':')
    time = '' if time is '::'
    gmt = matches.slice(6) is [undefined] ? 'Z' : matches.slice(6)
    datetime = day
    datetime += "T" + time if time
    datetime += gmt if gmt
    datetime.toString()

  convertDateToIcalTime: (date) =>
    date.toISOString().replace(/-|:|\.\d{3}/gi, '')



class CalDav
  constructor: (@url, @user, @password) ->

  get: (callback, datestart, dateend) =>
    jQuery.ajax
      url: @url
      method: "REPORT"
      data:  """
              <?xml version="1.0" encoding="utf-8" ?>
              <C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
                  <D:prop>
                      <C:calendar-data>
                          <C:expand start="#{datestart}" end="#{dateend}"/>
                      </C:calendar-data>
                      <D:getetag/>
                  </D:prop>
                  <C:filter>
                      <C:comp-filter name="VCALENDAR">
                          <C:comp-filter name="VEVENT">
                              <C:time-range start="#{datestart}" end="#{dateend}"/>
                          </C:comp-filter>
                      </C:comp-filter>
                  </C:filter>
              </C:calendar-query>
             """
      headers:
        "Depth": "1"
        "Content-Type": "application/xml"
      username: @user
      password: @password
      dataType: "xml"
      success: (xmlData) =>
        # fixing silly bug between chrome and firefox:
        # chrome does not accept cal\\:calendar-data due to the namespace prefix, while firefox does not accept
        # the string without the namespace. so we just filter for both variants
        # https://stackoverflow.com/questions/10181087/xml-findsomeelement-pulling-values-with-jquery-from-xml-with-namespace
        $(xmlData).find("cal\\:calendar-data, calendar-data").each (index, data) =>
          callback(@parseCalDav($(data).text()))

  parseCalDav: (calendarString) ->
    CalDavEntry = {}
    isSubElement = false
    subElementName = ""
    lines = calendarString.split '\r\n'
    for line in lines
      entry = line.split ':'
      label = entry.shift().split(';')[0]
      value = entry.join(':')
      if label is 'BEGIN'
        isSubElement = true
        subElementName = value
        CalDavEntry[value] = {}
        continue
      if label is 'END'
        isSubElement = false
        continue

      if isSubElement
        CalDavEntry[subElementName][label] = value
      else
        CalDavEntry[label] = value
    CalDavEntry



jQuery =>

  caldav = new CalDav("/baikal/cal.php/calendars/Reiner/default/", "User", "Password")
  calendar = new Calendar(caldav)


###
if Notification.permission is "granted"
  setTimeout ->
    new Notification "title", body: "notification body"
  , 1000
else if Notification.permission isnt 'denied'
  Notification.requestPermission (status) ->
    if Notification.permission is "granted"
      window.location.reload();
    else
      alert "Notifications are disabled."


###