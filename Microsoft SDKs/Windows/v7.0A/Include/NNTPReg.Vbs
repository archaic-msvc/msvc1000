'THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT 
'WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, 
'INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
'OF MERCHANTABILITY AND/OR FITNESS FOR A  PARTICULAR 
'PURPOSE

'------------------------------------------------------------------------------
'FILE DESCRIPTION: Script for registering for NNTP Protocol sinks. 
'
'File Name: nntpreg.vbs
' 
'
' Copyright (c) Microsoft Corporation 1993-1999. All rights reserved.
'------------------------------------------------------------------------------
Option Explicit

'
' these GUIDs are all defined in nntpfilt.idl
'
' the OnPostEarly event GUID
Const GUIDComCatOnPostEarly = "{C028FD86-F943-11d0-85BD-00C04FB960EA}"
' the OnPost event GUID
Const GUIDComCatOnPost = "{C028FD83-F943-11d0-85BD-00C04FB960EA}"
' the OnPostFinal event GUID
Const GUIDComCatOnPostFinal = "{C028FD85-F943-11d0-85BD-00C04FB960EA}"
' the NNTP source type
Const GUIDSourceType = "{C028FD82-F943-11d0-85BD-00C04FB960EA}"

' the NNTP service display name.  This is used to key which service to
' edit
Const szService = "nntpsvc"

' the event manager object.  This is used to communicate with the 
' event binding database.
Dim EventManager
Set EventManager = WScript.CreateObject("Event.Manager")

'
' register a new sink with event manager
'
' iInstance - the instance to work against
' szEvent - OnPostEarly, OnPost or OnPostFinal
' szDisplayName - the display name for this new sink
' szProgID - the progid to call for this event
' szRule - the rule to set for this event
'
public sub RegisterSink(iInstance, szEvent, szDisplayName, szProgID, szRule)
	Dim SourceType
	Dim szSourceDisplayName
	Dim Source
	Dim Binding
	Dim GUIDComCat
	Dim PrioVal

	' figure out which event they are trying to register with and set
	' the comcat for this event in GUIDComCat
	select case LCase(szEvent)
		case "onpostearly"
			GUIDComCat = GUIDComCatOnPostEarly
		case "onpost"
			GUIDComCat = GUIDComCatOnPost
		case "onpostfinal"
			GUIDComCat = GUIDComCatOnPostFinal
		case else
			WScript.echo "invalid event: " & szEvent
			exit sub
	end select

	' enumerate through each of the registered instances for the NNTP source
	' type and look for the display name that matches the instance display
	' name
	set SourceType = EventManager.SourceTypes(GUIDSourceType)
	szSourceDisplayName = szService & " " & iInstance
	for each Source in SourceType.Sources
		if Source.DisplayName = szSourceDisplayName then
			' we've found the desired instance.  now add a new binding
			' with the right event GUID.  by not specifying a GUID to the
			' Add method we get server events to create a new ID for this
			' event
			set Binding = Source.GetBindingManager.Bindings(GUIDComCat).Add("")
			' set the binding properties
			Binding.DisplayName = szDisplayName
			Binding.SinkClass = szProgID
			' register a rule with the binding
			Binding.SourceProperties.Add "Rule", szRule
			' register a priority with the binding
			PrioVal = GetNextPrio(Source, GUIDComCat)
			If PrioVal < 0 then
				WScript.Echo "assigning priority to default value (24575)"
				Binding.SourceProperties.Add "Priority", 24575
			else	
				WScript.Echo "assigning priority (" & PrioVal & " of 32767)"
				Binding.SourceProperties.Add "Priority", PrioVal
			end if
			' save the binding
			Binding.Save
			WScript.Echo "registered " & szDisplayName
			exit sub
		end if
	next
end sub

'
' iterate through the bindings in a source, find the binding
' with the lowest priority, and return the next priority value.
' If the next value exceeds the range, return -1.
'
public function GetNextPrio(oSource, GUIDComCat)
	' it's possible that priority values will not be
	' numbers, so we add error handling for this case
	on error resume next

	Dim Bindings
	Dim Binding
	Dim nLowestPrio
	Dim nPrioVal
	nLowestPrio = 0
	set Bindings = oSource.GetBindingManager.Bindings(GUIDComCat)
	' if the bindings collection is empty, then this is the first
	' sink.  It gets the highest priority (0).
	if Bindings.Count = 0 then
		GetNextPrio = 0
	else
		' get the lowest existing priority value
		for each Binding in Bindings
			nPrioVal = Binding.SourceProperties.Item("Priority")
			if CInt(nPrioVal) > nLowestPrio then
				if err.number = 13 then
					err.clear
				else
					nLowestPrio = CInt(nPrioVal)
				end if
			end if
		next 
		' assign priority values in increments of 10 so priorities
		' can be shuffled later without the need to reorder all
		' binding priorities.  Valid priority values are 0 - 32767
		if nLowestPrio + 10 > 32767 then
			GetNextPrio = -1
		else
			GetNextPrio = nLowestPrio + 10
		end if
	end if
end function

'
' unregister a previously registered sink
'
' iInstance - the instance to work against
' szEvent - OnPostEarly, OnPost or OnPostFinal
' szDisplayName - the display name of the event to remove
'
public sub UnregisterSink(iInstance, szEvent, szDisplayName)
	Dim SourceType
	Dim GUIDComCat
	Dim szSourceDisplayName
	Dim Source
	Dim Bindings
	Dim Binding

	select case LCase(szEvent)
		case "onpostearly"
			GUIDComCat = GUIDComCatOnPostEarly
		case "onpost"
			GUIDComCat = GUIDComCatOnPost
		case "onpostfinal"
			GUIDComCat = GUIDComCatOnPostFinal
		case else
			WScript.echo "invalid event: " & szEvent
			exit sub
	end select

	' find the source for this instance
	set SourceType = EventManager.SourceTypes(GUIDSourceType)
	szSourceDisplayName = szService & " " & iInstance
	for each Source in SourceType.Sources
		if Source.DisplayName = szSourceDisplayName then
			' find the binding by display name.  to do this we enumerate
			' all of the bindings and try to match on the display name
			set Bindings = Source.GetBindingManager.Bindings(GUIDComCat)
			for each Binding in Bindings
				if Binding.DisplayName = szDisplayName then
					' we've found the binding, now remove it
					Bindings.Remove(Binding.ID)
					WScript.Echo "removed " & szDisplayName & " " & Binding.ID
				end if
			next
		end if
	next
end sub

'
' add or remove a property from the source or sink propertybag for an event
'
' iInstance - the NNTP instance to edit
' szEvent - the event type (OnPostEarly, OnPost or OnPostFinal)
' szDisplayName - the display name of the event
' szPropertyBag - the property bag to edit ("source" or "sink")
' szOperation - "add" or "remove"
' szPropertyName - the name to edit in the property bag
' szPropertyValue - the value to assign to the name (ignored for remove)
'
public sub EditProperty(iInstance, szEvent, szDisplayName, szPropertyBag, szOperation, szPropertyName, szPropertyValue)
	Dim SourceType
	Dim GUIDComCat
	Dim szSourceDisplayName
	Dim Source
	Dim Bindings
	Dim Binding
	Dim PropertyBag

	select case LCase(szEvent)
		case "onpostearly"
			GUIDComCat = GUIDComCatOnPostEarly
		case "onpost"
			GUIDComCat = GUIDComCatOnPost
		case "onpostfinal"
			GUIDComCat = GUIDComCatOnPostFinal
		case else
			WScript.echo "invalid event: " & szEvent
			exit sub
	end select

	' find the source for this instance
	set SourceType = EventManager.SourceTypes(GUIDSourceType)
	szSourceDisplayName = szService & " " & iInstance
	for each Source in SourceType.Sources
		if Source.DisplayName = szSourceDisplayName then
			set Bindings = Source.GetBindingManager.Bindings(GUIDComCat)
			' find the binding by display name.  to do this we enumerate
			' all of the bindings and try to match on the display name
			for each Binding in Bindings
				if Binding.DisplayName = szDisplayName then
					' figure out which set of properties we want to modify
					' based on the szPropertyBag parameter
					select case LCase(szPropertyBag)
						case "source"
							set PropertyBag = Binding.SourceProperties
						case "sink"
							set PropertyBag = Binding.SinkProperties
						case else
							WScript.echo "invalid propertybag: " & szPropertyBag
							exit sub
					end select
					' figure out what operation we want to perform
					select case LCase(szOperation)
						case "remove"
							' they want to remove szPropertyName from the
							' property bag
							PropertyBag.Remove szPropertyName
							WScript.echo "removed property " & szPropertyName
						case "add"
							' add szPropertyName to the property bag and 
							' set its value to szValue.  if this value
							' already exists then this will change  the value
							' it to szValue.
							PropertyBag.Add szPropertyName, szPropertyValue
							WScript.echo "set property " & szPropertyName & " to " & szPropertyValue
						case else
							WScript.echo "invalid operation: " & szOperation
							exit sub
					end select
					' save the binding
					Binding.Save
				end if
			next
		end if
	next
end sub

'
' this helper function takes an IEventSource object and a event category
' and dumps all of the bindings for this category under the source
'
' Source - the IEventSource object to display the bindings for
' GUIDComCat - the event category to display the bindings for
'
public sub DisplaySinksHelper(Source, GUIDComCat)
	Dim Binding
	Dim propval
	' walk each of the registered bindings for this component category
	for each Binding in Source.GetBindingManager.Bindings(GUIDComCat)
		' display the binding properties
		WScript.echo "    Binding " & Binding.ID & " {"
		WScript.echo "      DisplayName = " & Binding.DisplayName
		WScript.echo "      SinkClass = " & Binding.SinkClass
		if Binding.Enabled = True then
			WScript.echo "      Status = Enabled"
		else
			WScript.echo "      Status = Disabled"
		end if

		' walk each of the source properties and display them
		WScript.echo "      SourceProperties {"
		for each propval in Binding.SourceProperties
			WScript.echo "        " & propval & " = " & Binding.SourceProperties.Item(propval)
		next
		WScript.echo "      }"

		' walk each of the sink properties and display them
		WScript.echo "      SinkProperties {"
		for each propval in Binding.SinkProperties
			WScript.echo "        " & propval & " = " & Binding.SinkProperties.Item(propval)
		next
		WScript.echo "      }"
		WScript.echo "    }"
	next
end sub

' check for a previously registered sink with the passed in name
'
' iInstance - the instance to work against
' szEvent - OnMessage
' szDisplayName - the display name of the event to check
' bCheckError - Any errors returned
public sub CheckSink(iInstance, szEvent, szDisplayName, bCheckError)
	Dim SourceType
	Dim GUIDComCat
	Dim szSourceDisplayName
	Dim Source
	Dim Bindings
	Dim Binding

	bCheckError = FALSE
	select case LCase(szEvent)
		case "onpostearly"
			GUIDComCat = GUIDComCatOnPostEarly		
		case "onpost"
			GUIDComCat = GUIDComCatOnPost
		case "onpostfinal"
			GUIDComCat = GUIDComCatOnPostFinal
		case else
			WScript.echo "invalid event: " & szEvent
			exit sub
	end select

	' find the source for this instance
	set SourceType = EventManager.SourceTypes(GUIDSourceType)
	szSourceDisplayName = szService & " " & iInstance
	for each Source in SourceType.Sources
		if Source.DisplayName = szSourceDisplayName then
			' find the binding by display name.  to do this we enumerate
			' all of the bindings and try to match on the display name
			set Bindings = Source.GetBindingManager.Bindings(GUIDComCat)
			for each Binding in Bindings
				if Binding.DisplayName = szDisplayName then
					' we've found the binding, now log an error
					WScript.Echo "Binding with the name " & szDisplayName & " already exists"
					exit sub 
				end if
			next
		end if
	next
	bCheckError = TRUE
end sub

'
'
' dumps all of the information in the binding database related to NNTP
'
public sub DisplaySinks
	Dim SourceType
	Dim Source

	' look for each of the sources registered for the NNTP source type
	set SourceType = EventManager.SourceTypes(GUIDSourceType)
	for each Source in SourceType.Sources
		' display the source properties
		WScript.echo "Source " & Source.ID & " {"
		WScript.echo "  DisplayName = " & Source.DisplayName
		' display all of the sinks registered for the OnPostEarly event
		WScript.echo "  OnPostEarly Sinks {"
		call DisplaySinksHelper(Source, GUIDComCatOnPostEarly)
		WScript.echo "  }"
		' display all of the sinks registered for the OnPost event
		WScript.echo "  OnPost Sinks {"
		call DisplaySinksHelper(Source, GUIDComCatOnPost)
		WScript.echo "  }"
		' display all of the sinks registered for the OnPostFinal event
		WScript.echo "  OnPostFinal Sinks {"
		call DisplaySinksHelper(Source, GUIDComCatOnPostFinal)
		WScript.echo "  }"
		WScript.echo "}"
	next
end sub

'
' enable/disable a registered sink
'
' iInstance - the instance to work against
' szEvent - OnArrival
' szDisplayName - the display name for this new sink
'
public sub SetSinkEnabled(iInstance, szEvent, szDisplayName, szEnable)
	Dim SourceType
	Dim GUIDComCat
	Dim szSourceDisplayName
	Dim Source
	Dim Bindings
	Dim Binding

	select case LCase(szEvent)
		case "onpostearly"
			GUIDComCat = GUIDComCatOnPostEarly		
		case "onpost"
			GUIDComCat = GUIDComCatOnPost
		case "onpostfinal"
			GUIDComCat = GUIDComCatOnPostFinal
		case else
			WScript.echo "invalid event: " + szEvent
			exit sub
	end select

	' find the source for this instance
	set SourceType = EventManager.SourceTypes(GUIDSourceType)
	szSourceDisplayName = szService + " " + iInstance
	for each Source in SourceType.Sources
		if Source.DisplayName = szSourceDisplayName then
			' find the binding by display name.  to do this we enumerate
			' all of the bindings and try to match on the display name
			set Bindings = Source.GetBindingManager.Bindings(GUIDComCat)
			for each Binding in Bindings
				if Binding.DisplayName = szDisplayName then
					' we've found the binding, now enable/disable it
					' we don't need "case else' because szEnable's value
					' is set internally, not by users
					select case LCase(szEnable)
						case "true"
							Binding.Enabled = True
							Binding.Save
							WScript.Echo "enabled " + szDisplayName + " " + Binding.ID
						case "false"
							Binding.Enabled = False
							Binding.Save
							WScript.Echo "disabled " + szDisplayName + " " + Binding.ID
						end select
				end if
			next
		end if
	next
end sub

' 
' display usage information for this script
'
public sub DisplayUsage
	WScript.echo "usage: cscript nntpreg.vbs <command> <arguments>"
	WScript.echo "  commands:"
	WScript.echo "    /add <Instance> <Event> <DisplayName> <SinkClass> <Rule>"
	WScript.echo "    /remove <Instance> <Event> <DisplayName>"
	WScript.echo "    /setprop <Instance> <Event> <DisplayName> <PropertyBag> <PropertyName> "
	WScript.echo "             <PropertyValue>"
	WScript.echo "    /delprop <Instance> <Event> <DisplayName> <PropertyBag> <PropertyName>"
	WScript.echo "    /enable <Instance> <Event> <DisplayName>"
	WScript.echo "    /disable <Instance> <Event> <DisplayName>"
	WScript.echo "    /enum"
	WScript.echo "  arguments:"
	WScript.echo "    <Instance> is the NNTP instance to work against"
	WScript.echo "    <Event> can be OnPostEarly, OnPost or OnPostFinal"
	WScript.echo "    <DisplayName> is the display name of the event to edit"
	WScript.echo "    <SinkClass> is the sink class for the event"
	WScript.echo "    <Rule> is the rule to use for the event"
	WScript.echo "    <PropertyBag> can be Source or Sink"
	WScript.echo "    <PropertyName> is the name of the property to edit"
	WScript.echo "    <PropertyValue> is the value to assign to the property"
end sub


Dim iInstance
Dim szEvent
Dim szDisplayName
Dim szSinkClass
Dim szRule
Dim szPropertyBag
Dim szPropertyName
Dim szPropertyValue
Dim bCheck

'
' this is the main body of our script.  it reads the command line parameters
' specified and then calls the appropriate function to perform the operation
'
if WScript.Arguments.Count = 0 then
	call DisplayUsage
else 
	Select Case LCase(WScript.Arguments(0))
		Case "/add"
			if not WScript.Arguments.Count = 6 then
				call DisplayUsage
			else
				iInstance = WScript.Arguments(1)
				szEvent = WScript.Arguments(2)
				szDisplayName = WScript.Arguments(3)
				szSinkClass = WScript.Arguments(4)
				szRule = WScript.Arguments(5)
				call CheckSink(iInstance, szEvent, szDisplayName, bCheck)
				if bCheck = TRUE then
					call RegisterSink(iInstance, szEvent, szDisplayName, szSinkClass, szRule)
				End if
			end if
		Case "/remove"
			if not WScript.Arguments.Count = 4 then
				call DisplayUsage
			else
				iInstance = WScript.Arguments(1)
				szEvent = WScript.Arguments(2)
				szDisplayName = WScript.Arguments(3)
				call UnregisterSink(iInstance, szEvent, szDisplayName)		
			end if	
		Case "/setprop"
			if not WScript.Arguments.Count = 7 then
				call DisplayUsage
			else
				iInstance = WScript.Arguments(1)
				szEvent = WScript.Arguments(2)
				szDisplayName = WScript.Arguments(3)
				szPropertyBag = WScript.Arguments(4)
				szPropertyName = WScript.Arguments(5)
				szPropertyValue = WScript.Arguments(6)
				call EditProperty(iInstance, szEvent, szDisplayName, szPropertyBag, "add", szPropertyName, szPropertyValue)
			end if
		Case "/delprop"
			if not WScript.Arguments.Count = 6 then
				call DisplayUsage
			else
				iInstance = WScript.Arguments(1)
				szEvent = WScript.Arguments(2)
				szDisplayName = WScript.Arguments(3)
				szPropertyBag = WScript.Arguments(4)
				szPropertyName = WScript.Arguments(5)
				call EditProperty(iInstance, szEvent, szDisplayName, szPropertyBag, "remove", szPropertyName, "")		
			end if
		Case "/enable"
			if not WScript.Arguments.Count = 4 then
				call DisplayUsage
			else
				iInstance = WScript.Arguments(1)
				szEvent = WScript.Arguments(2)
				szDisplayName = WScript.Arguments(3)
				call SetSinkEnabled(iInstance, szEvent, szDisplayName, "True")
			end if
		Case "/disable"
			if not WScript.Arguments.Count = 4 then
				call DisplayUsage
			else
				iInstance = WScript.Arguments(1)
				szEvent = WScript.Arguments(2)
				szDisplayName = WScript.Arguments(3)
				call SetSinkEnabled(iInstance, szEvent, szDisplayName, "False")
			end if
		Case "/enum"
			if not WScript.Arguments.Count = 1 then
				call DisplayUsage
			else
				call DisplaySinks
			end if
		Case Else
			call DisplayUsage
	End Select
end if

'' SIG '' Begin signature block
'' SIG '' MIIXPAYJKoZIhvcNAQcCoIIXLTCCFykCAQExCzAJBgUr
'' SIG '' DgMCGgUAMGcGCisGAQQBgjcCAQSgWTBXMDIGCisGAQQB
'' SIG '' gjcCAR4wJAIBAQQQTvApFpkntU2P5azhDxfrqwIBAAIB
'' SIG '' AAIBAAIBAAIBADAhMAkGBSsOAwIaBQAEFBYGE0UfavVK
'' SIG '' Ib5a4v/38mEUAtiaoIISMTCCBGAwggNMoAMCAQICCi6r
'' SIG '' EdxQ/1ydy8AwCQYFKw4DAh0FADBwMSswKQYDVQQLEyJD
'' SIG '' b3B5cmlnaHQgKGMpIDE5OTcgTWljcm9zb2Z0IENvcnAu
'' SIG '' MR4wHAYDVQQLExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
'' SIG '' ITAfBgNVBAMTGE1pY3Jvc29mdCBSb290IEF1dGhvcml0
'' SIG '' eTAeFw0wNzA4MjIyMjMxMDJaFw0xMjA4MjUwNzAwMDBa
'' SIG '' MHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
'' SIG '' dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
'' SIG '' aWNyb3NvZnQgQ29ycG9yYXRpb24xIzAhBgNVBAMTGk1p
'' SIG '' Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBMIIBIjANBgkq
'' SIG '' hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAt3l91l2zRTmo
'' SIG '' NKwx2vklNUl3wPsfnsdFce/RRujUjMNrTFJi9JkCw03Y
'' SIG '' SWwvJD5lv84jtwtIt3913UW9qo8OUMUlK/Kg5w0jH9FB
'' SIG '' JPpimc8ZRaWTSh+ZzbMvIsNKLXxv2RUeO4w5EDndvSn0
'' SIG '' ZjstATL//idIprVsAYec+7qyY3+C+VyggYSFjrDyuJSj
'' SIG '' zzimUIUXJ4dO3TD2AD30xvk9gb6G7Ww5py409rQurwp9
'' SIG '' YpF4ZpyYcw2Gr/LE8yC5TxKNY8ss2TJFGe67SpY7UFMY
'' SIG '' zmZReaqth8hWPp+CUIhuBbE1wXskvVJmPZlOzCt+M26E
'' SIG '' RwbRntBKhgJuhgCkwIffUwIDAQABo4H6MIH3MBMGA1Ud
'' SIG '' JQQMMAoGCCsGAQUFBwMDMIGiBgNVHQEEgZowgZeAEFvQ
'' SIG '' cO9pcp4jUX4Usk2O/8uhcjBwMSswKQYDVQQLEyJDb3B5
'' SIG '' cmlnaHQgKGMpIDE5OTcgTWljcm9zb2Z0IENvcnAuMR4w
'' SIG '' HAYDVQQLExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
'' SIG '' BgNVBAMTGE1pY3Jvc29mdCBSb290IEF1dGhvcml0eYIP
'' SIG '' AMEAizw8iBHRPvZj7N9AMA8GA1UdEwEB/wQFMAMBAf8w
'' SIG '' HQYDVR0OBBYEFMwdznYAcFuv8drETppRRC6jRGPwMAsG
'' SIG '' A1UdDwQEAwIBhjAJBgUrDgMCHQUAA4IBAQB7q65+Siby
'' SIG '' zrxOdKJYJ3QqdbOG/atMlHgATenK6xjcacUOonzzAkPG
'' SIG '' yofM+FPMwp+9Vm/wY0SpRADulsia1Ry4C58ZDZTX2h6t
'' SIG '' KX3v7aZzrI/eOY49mGq8OG3SiK8j/d/p1mkJkYi9/uEA
'' SIG '' uzTz93z5EBIuBesplpNCayhxtziP4AcNyV1ozb2AQWtm
'' SIG '' qLu3u440yvIDEHx69dLgQt97/uHhrP7239UNs3DWkuNP
'' SIG '' tjiifC3UPds0C2I3Ap+BaiOJ9lxjj7BauznXYIxVhBoz
'' SIG '' 9TuYoIIMol+Lsyy3oaXLq9ogtr8wGYUgFA0qvFL0QeBe
'' SIG '' MOOSKGmHwXDi86erzoBCcnYOMIIEejCCA2KgAwIBAgIK
'' SIG '' YQHPPgAAAAAADzANBgkqhkiG9w0BAQUFADB5MQswCQYD
'' SIG '' VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
'' SIG '' A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
'' SIG '' IENvcnBvcmF0aW9uMSMwIQYDVQQDExpNaWNyb3NvZnQg
'' SIG '' Q29kZSBTaWduaW5nIFBDQTAeFw0wOTEyMDcyMjQwMjla
'' SIG '' Fw0xMTAzMDcyMjQwMjlaMIGDMQswCQYDVQQGEwJVUzET
'' SIG '' MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
'' SIG '' bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
'' SIG '' aW9uMQ0wCwYDVQQLEwRNT1BSMR4wHAYDVQQDExVNaWNy
'' SIG '' b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEB
'' SIG '' AQUAA4IBDwAwggEKAoIBAQC9MIn7RXKoU2ueiU8AI8C+
'' SIG '' 1B09sVlAOPNzkYIm5pYSAFPZHIIOPM4du733Qo2X1Pw4
'' SIG '' GuS5+ePs02EDv6DT1nVNXEap7V7w0uJpWxpz6rMcjQTN
'' SIG '' KUSgZFkvHphdbserGDmCZcSnvKt1iBnqh5cUJrN/Jnak
'' SIG '' 1Dg5hOOzJtUY+Svp0skWWlQh8peNh4Yp/vRJLOaL+AQ/
'' SIG '' fc3NlpKGDXED4tD+DEI1/9e4P92ORQp99tdLrVvwdnId
'' SIG '' dyN9iTXEHF2yUANLR20Hp1WImAaApoGtVE7Ygdb6v0LA
'' SIG '' Mb5VDZnVU0kSMOvlpYh8XsR6WhSHCLQ3aaDrMiSMCOv5
'' SIG '' 1BS64PzN6qQVAgMBAAGjgfgwgfUwEwYDVR0lBAwwCgYI
'' SIG '' KwYBBQUHAwMwHQYDVR0OBBYEFDh4BXPIGzKbX5KGVa+J
'' SIG '' usaZsXSOMA4GA1UdDwEB/wQEAwIHgDAfBgNVHSMEGDAW
'' SIG '' gBTMHc52AHBbr/HaxE6aUUQuo0Rj8DBEBgNVHR8EPTA7
'' SIG '' MDmgN6A1hjNodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
'' SIG '' cGtpL2NybC9wcm9kdWN0cy9DU1BDQS5jcmwwSAYIKwYB
'' SIG '' BQUHAQEEPDA6MDgGCCsGAQUFBzAChixodHRwOi8vd3d3
'' SIG '' Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL0NTUENBLmNy
'' SIG '' dDANBgkqhkiG9w0BAQUFAAOCAQEAKAODqxMN8f4Rb0J2
'' SIG '' 2EOruMZC+iRlNK51sHEwjpa2g/py5P7NN+c6cJhRIA66
'' SIG '' cbTJ9NXkiugocHPV7eHCe+7xVjRagILrENdyA+oSTuzd
'' SIG '' DYx7RE8MYXX9bpwH3c4rWhgNObBg/dr/BKoCo9j6jqO7
'' SIG '' vcFqVDsxX+QsbsvxTSoc8h52e4avxofWsSrtrMwOwOSf
'' SIG '' f+jP6IRyVIIYbirInpW0Gh7Bb5PbYqbBS2utye09kuOy
'' SIG '' L6t6dzlnagB7gp0DEN5jlUkmQt6VIsGHC9AUo1/cczJy
'' SIG '' Nh7/yCnFJFJPZkjJHR2pxSY5aVBOp+zCBmwuchvxIdpt
'' SIG '' JEiAgRVAfJ/MdDhKTzCCBJ0wggOFoAMCAQICEGoLmU/A
'' SIG '' ACWrEdtFH1h6Z6IwDQYJKoZIhvcNAQEFBQAwcDErMCkG
'' SIG '' A1UECxMiQ29weXJpZ2h0IChjKSAxOTk3IE1pY3Jvc29m
'' SIG '' dCBDb3JwLjEeMBwGA1UECxMVTWljcm9zb2Z0IENvcnBv
'' SIG '' cmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgUm9vdCBB
'' SIG '' dXRob3JpdHkwHhcNMDYwOTE2MDEwNDQ3WhcNMTkwOTE1
'' SIG '' MDcwMDAwWjB5MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
'' SIG '' V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
'' SIG '' A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYD
'' SIG '' VQQDExpNaWNyb3NvZnQgVGltZXN0YW1waW5nIFBDQTCC
'' SIG '' ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANw3
'' SIG '' bvuvyEJKcRjIzkg+U8D6qxS6LDK7Ek9SyIPtPjPZSTGS
'' SIG '' KLaRZOAfUIS6wkvRfwX473W+i8eo1a5pcGZ4J2botrfv
'' SIG '' hbnN7qr9EqQLWSIpL89A2VYEG3a1bWRtSlTb3fHev5+D
'' SIG '' x4Dff0wCN5T1wJ4IVh5oR83ZwHZcL322JQS0VltqHGP/
'' SIG '' gHw87tUEJU05d3QHXcJc2IY3LHXJDuoeOQl8dv6dbG56
'' SIG '' 4Ow+j5eecQ5fKk8YYmAyntKDTisiXGhFi94vhBBQsvm1
'' SIG '' Go1s7iWbE/jLENeFDvSCdnM2xpV6osxgBuwFsIYzt/iU
'' SIG '' W4RBhFiFlG6wHyxIzG+cQ+Bq6H8mjmsCAwEAAaOCASgw
'' SIG '' ggEkMBMGA1UdJQQMMAoGCCsGAQUFBwMIMIGiBgNVHQEE
'' SIG '' gZowgZeAEFvQcO9pcp4jUX4Usk2O/8uhcjBwMSswKQYD
'' SIG '' VQQLEyJDb3B5cmlnaHQgKGMpIDE5OTcgTWljcm9zb2Z0
'' SIG '' IENvcnAuMR4wHAYDVQQLExVNaWNyb3NvZnQgQ29ycG9y
'' SIG '' YXRpb24xITAfBgNVBAMTGE1pY3Jvc29mdCBSb290IEF1
'' SIG '' dGhvcml0eYIPAMEAizw8iBHRPvZj7N9AMBAGCSsGAQQB
'' SIG '' gjcVAQQDAgEAMB0GA1UdDgQWBBRv6E4/l7k0q0uGj7yc
'' SIG '' 6qw7QUPG0DAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMA
'' SIG '' QTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAN
'' SIG '' BgkqhkiG9w0BAQUFAAOCAQEAlE0RMcJ8ULsRjqFhBwEO
'' SIG '' jHBFje9zVL0/CQUt/7hRU4Uc7TmRt6NWC96Mtjsb0fus
'' SIG '' p8m3sVEhG28IaX5rA6IiRu1stG18IrhG04TzjQ++B4o2
'' SIG '' wet+6XBdRZ+S0szO3Y7A4b8qzXzsya4y1Ye5y2PENtEY
'' SIG '' Ib923juasxtzniGI2LS0ElSM9JzCZUqaKCacYIoPO8cT
'' SIG '' ZXhIu8+tgzpPsGJY3jDp6Tkd44ny2jmB+RMhjGSAYwYE
'' SIG '' lvKaAkMve0aIuv8C2WX5St7aA3STswVuDMyd3ChhfEjx
'' SIG '' F5wRITgCHIesBsWWMrjlQMZTPb2pid7oZjeN9CKWnMyw
'' SIG '' d1RROtZyRLIj9jCCBKowggOSoAMCAQICCmEGlC0AAAAA
'' SIG '' AAkwDQYJKoZIhvcNAQEFBQAweTELMAkGA1UEBhMCVVMx
'' SIG '' EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
'' SIG '' ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
'' SIG '' dGlvbjEjMCEGA1UEAxMaTWljcm9zb2Z0IFRpbWVzdGFt
'' SIG '' cGluZyBQQ0EwHhcNMDgwNzI1MTkwMjE3WhcNMTMwNzI1
'' SIG '' MTkxMjE3WjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgT
'' SIG '' Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
'' SIG '' BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjENMAsG
'' SIG '' A1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0Ug
'' SIG '' RVNOOjdBODItNjg4QS05RjkyMSUwIwYDVQQDExxNaWNy
'' SIG '' b3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIIBIjANBgkq
'' SIG '' hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAlYEKIEIYUXrZ
'' SIG '' le2b/dyH0fsOjxPqqjcoEnb+TVCrdpcqk0fgqVZpAuWU
'' SIG '' fk2F239x73UA27tDbPtvrHHwK9F8ks6UF52hxbr5937d
'' SIG '' YeEtMB6cJi12P+ZGlo6u2Ik32Mzv889bw/xo4PJkj5vo
'' SIG '' wxL5o76E/NaLzgU9vQF2UCcD+IS3FoaNYL5dKSw8z6X9
'' SIG '' mFo1HU8WwDjYHmE/PTazVhQVd5U7EPoAsJPiXTerJ7tj
'' SIG '' LEgUgVXjbOqpK5WNiA5+owCldyQHmCpwA7gqJJCa3sWi
'' SIG '' Iku/TFkGd1RyQ7A+ZN2ThAhYtv7ph0kJNrOz+DOpfkyi
'' SIG '' eX8yWSkOnrX14DyeP+xGOwIDAQABo4H4MIH1MB0GA1Ud
'' SIG '' DgQWBBQolYi/Ajvr2pS6fUYP+sv0fp3/0TAfBgNVHSME
'' SIG '' GDAWgBRv6E4/l7k0q0uGj7yc6qw7QUPG0DBEBgNVHR8E
'' SIG '' PTA7MDmgN6A1hjNodHRwOi8vY3JsLm1pY3Jvc29mdC5j
'' SIG '' b20vcGtpL2NybC9wcm9kdWN0cy90c3BjYS5jcmwwSAYI
'' SIG '' KwYBBQUHAQEEPDA6MDgGCCsGAQUFBzAChixodHRwOi8v
'' SIG '' d3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL3RzcGNh
'' SIG '' LmNydDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNVHQ8B
'' SIG '' Af8EBAMCBsAwDQYJKoZIhvcNAQEFBQADggEBAADurPzi
'' SIG '' 0ohmyinjWrnNAIJ+F1zFJFkSu6j3a9eH/o3LtXYfGyL2
'' SIG '' 9+HKtLlBARo3rUg3lnD6zDOnKIy4C7Z0Eyi3s3XhKgni
'' SIG '' i0/fmD+XtzQSgeoQ3R3cumTPTlA7TIr9Gd0lrtWWh+pL
'' SIG '' xOXw+UEXXQHrV4h9dnrlb/6HIKyTnIyav18aoBUwJOCi
'' SIG '' fmGRHSkpw0mQOkODie7e1YPdTyw1O+dBQQGqAAwL8tZJ
'' SIG '' G85CjXuw8y2NXSnhvo1/kRV2tGD7FCeqbxJjQihYOoo7
'' SIG '' i0Dkt8XMklccRlZrj8uSTVYFAMr4MEBFTt8ZiL31EPDd
'' SIG '' Gt8oHrRR8nfgJuO7CYES3B460EUxggR3MIIEcwIBATCB
'' SIG '' hzB5MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
'' SIG '' Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
'' SIG '' TWljcm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYDVQQDExpN
'' SIG '' aWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQQIKYQHPPgAA
'' SIG '' AAAADzAJBgUrDgMCGgUAoIGiMBkGCSqGSIb3DQEJAzEM
'' SIG '' BgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
'' SIG '' BgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQovINEE5bY
'' SIG '' i3FbAmRBUmvKOymTnDBCBgorBgEEAYI3AgEMMTQwMqAY
'' SIG '' gBYATgBOAFQAUABSAGUAZwAuAFYAYgBzoRaAFGh0dHA6
'' SIG '' Ly9taWNyb3NvZnQuY29tMA0GCSqGSIb3DQEBAQUABIIB
'' SIG '' AEbumYe9969eOHIpT+GcV3Iw9V7YidV75F5/sJfbC9KQ
'' SIG '' PIIUBG7HNCL+zBTCvgJRNXbi5mh0GJF+u65hDTNXOYXd
'' SIG '' TgCqgYzOHEL8ugx2gEtoLEbXUuvvEn2ikWxgHj5Cir5w
'' SIG '' IsGs6wTCkOpI1Cog3ItqXrXIgYZ308wkHp+7IsD2HKNL
'' SIG '' xF1KnaueRxx7NYpFykIEZkQoM5k79iXj2xS5eNAixb/P
'' SIG '' UWCZVca4UM+IY98XWosC20miE+zOA2c+srntfSkZMS+B
'' SIG '' mlQczucesC5fhNAFgPD1LDd6BMy09UpaXVrnPDv4x0VS
'' SIG '' H7BwOOXf++6zsDH6Uk/S5913ii57iDN1ULWhggIfMIIC
'' SIG '' GwYJKoZIhvcNAQkGMYICDDCCAggCAQEwgYcweTELMAkG
'' SIG '' A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
'' SIG '' BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
'' SIG '' dCBDb3Jwb3JhdGlvbjEjMCEGA1UEAxMaTWljcm9zb2Z0
'' SIG '' IFRpbWVzdGFtcGluZyBQQ0ECCmEGlC0AAAAAAAkwBwYF
'' SIG '' Kw4DAhqgXTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcB
'' SIG '' MBwGCSqGSIb3DQEJBTEPFw0xMDAzMTkxNzQ5NTFaMCMG
'' SIG '' CSqGSIb3DQEJBDEWBBRt40Wem8S+FSMqDyaTT86dTxAq
'' SIG '' FzANBgkqhkiG9w0BAQUFAASCAQB6zWtMIc5wysK8f2dx
'' SIG '' eJrnxNzin7UiF7dLg5vhVcs55fJsygb2Lz0CEV94JbjP
'' SIG '' ImGa4kQ5/dLtcnFZeBLHIQGfEXVAWrWWlOP5mEeIiMg9
'' SIG '' /4+6fy8Ozz5uuMYTOmbg7umg36NTaNZ7t25JZ0HhcHQA
'' SIG '' 2zNdLFbWDGldTgbEi9r/vprMqxmQ93/29vWRaxsNXA0N
'' SIG '' 6O8IzvHcloY2dMIPXOUhod8+tXAqRqYZnVqDjepqz1WC
'' SIG '' p3tTiMACbwZB+ryu+P9lucUPHv8NJIkW7eFKbxjLl8gF
'' SIG '' AbrmI7Fw0kRi09DOJW2AxQ0ylq8ISLPf6uPBHvQ3HFjp
'' SIG '' mdpQC1gq8VU/l+MY
'' SIG '' End signature block
