class DateUtility
	@convertICalTimeToISOTime: (time) =>
		matches = time.match(/(\d{4})(\d{2})(\d{2})T?(\d{2})?(\d{2})?(\d{2})?(Z?)/i)
		matches.shift()
		day = matches.slice(0, 3).join('-')
		time = matches.slice(3, 6).join(':')
		time = '' if time is '::'
		gmt = if matches.slice(6) is [undefined] then 'Z' else matches.slice(6)
		datetime = day
		datetime += "T" + time if time
		datetime += gmt if gmt
		datetime

	@convertDateToIcalTime: (date) =>
		date.toISOString().replace(/-|:|\.\d{3}/gi, '')


class Calendar
	constructor: (@caldav) ->
		@calendar = jQuery('#calendar')
		@calendar.fullCalendar
			firstDay: 1
			header:
				left: 'prev,next today'
				center: 'title'
				right: 'month,agendaWeek,agendaDay'
			timeFormat: 'HH:mm{ - HH:mm}\n'
			ignoreTimezone: false
			contentHeight: jQuery(window).height() - 250
			events: (viewStartDate, viewEndDate, callback) =>
				startDate = DateUtility.convertDateToIcalTime(viewStartDate)
				endDate = DateUtility.convertDateToIcalTime(viewEndDate)
				@caldav.get startDate, endDate, (calDavEntry) =>
					@addCalendarEntry(calDavEntry)
					callback()

	addCalendarEntry: (calDavEntry) =>
		if calDavEntry?.VEVENT?
			if calDavEntry.VEVENT.DTEND
				end = DateUtility.convertICalTimeToISOTime(calDavEntry.VEVENT.DTEND)
			event = {
				id: calDavEntry.VEVENT.UID
				title: calDavEntry.VEVENT.SUMMARY
				start: DateUtility.convertICalTimeToISOTime(calDavEntry.VEVENT.DTSTART)
			}
			if end
				event.end = end
				event.allDay = false
			# TODO: remove renderEvent and render it in the fullCalendar constructor via callback
			@calendar.fullCalendar('renderEvent', event)


class CalDav
	constructor: (@userData) ->

		# TODO: this method should be moved to calendar...the caldav class should be used only to parse caldav data
	get: (datestart, dateend, callback) =>
		jQuery.ajax
			url: @userData.url
			method: "REPORT"
			data: """
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
			username: @userData.user
			password: @userData.password
			dataType: "xml"
			success: (xmlData) =>
				# fixing silly bug between chrome and firefox:
				# chrome does not accept cal\\:calendar-data due to the namespace prefix, while firefox does not accept
				# the string without the namespace. so we just filter for both variants
				# https://stackoverflow.com/questions/10181087/xml-findsomeelement-pulling-values-with-jquery-from-xml-with-namespace
				foundElements = $(xmlData).find("cal\\:calendar-data, calendar-data")
				if foundElements.size() is 0
					if $(xmlData).find("d\\:multistatus, multistatus").size() > 0
						callback(true)
				foundElements.each (index, data) =>
					callback(@parseCalDav($(data).text()))
			error: =>
				callback(false)

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


class UserData
	constructor: ->
		@localstorage = window.localStorage
		@prefix = "caldav.webclient."

	fetchDataFromForm: =>
		@url = jQuery('#url').val()
		@user = jQuery('#user').val()
		@password = jQuery('#password').val()

	setDataToForm: =>
		jQuery('#url').val(@url)
		jQuery('#user').val(@user)
		jQuery('#password').val(@password)

	loadDataFromLocalStorage: =>
		@url = @localstorage.getItem @prefix + "url"
		@user = @localstorage.getItem @prefix + "user"
		@password = @localstorage.getItem @prefix + "password"
		true if @url

	saveDataToLocalStorage: =>
		@localstorage.setItem @prefix + "url", @url
		@localstorage.setItem @prefix + "user", @user
		@localstorage.setItem @prefix + "password", @password


jQuery =>
	userdata = new UserData()
	caldav = new CalDav(userdata)
	calendar = null

	if userdata.loadDataFromLocalStorage()
		jQuery('#calendar, #login').toggleClass 'hidden'
		calendar = new Calendar(caldav) if not calendar

	jQuery('#url, #user, #password').on 'keydown', (event) =>
		if event.keyCode is 13
			userdata.fetchDataFromForm()
			today = DateUtility.convertDateToIcalTime(new Date())
			tomorrowDate = new Date()
			tomorrowDate.setDate(tomorrowDate.getDate() + 1);
			tomorrow = DateUtility.convertDateToIcalTime(tomorrowDate)
			caldav.get today, tomorrow, (data) =>
				if data
					userdata.saveDataToLocalStorage()
					jQuery('#calendar, #login').toggleClass 'hidden'
					calendar = new Calendar(caldav) if not calendar
					$('#login input').removeClass 'error'
				else
					$('#login input').addClass 'error'

	jQuery('#changecredentials').on 'click', =>
		jQuery('#calendar, #login').toggleClass 'hidden'
		userdata.setDataToForm()


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