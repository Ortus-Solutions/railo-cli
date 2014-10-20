<cfparam name="addClosingHTMLTags" default="#true#" type="boolean"><cfoutput>
Railo #server.railo.version# Error (#catch.type#)
<cfparam name="catch.message" default="">
<cfparam name="catch.detail" default="">
Message: #replace( HTMLEditFormat( trim( catch.message ) ), chr(10), '<br>', 'all' )#
<cfif len( catch.detail )>
Detail:
  #replace( HTMLEditFormat( trim( catch.detail ) ), chr(10), '<br>', 'all' )#
</cfif>
<cfif structkeyexists( catch, 'errorcode' ) && len( catch.errorcode ) && catch.errorcode NEQ 0>
Error Code: #catch.errorcode#
</cfif>
<cfif structKeyExists( catch, 'extendedinfo' ) && len( catch.extendedinfo )>
Extended Info: #HTMLEditFormat( catch.extendedinfo )#
</cfif>
<cfif structKeyExists( catch, 'additional' )>
	<cfloop collection="#catch.additional#" item="key">
  #key#: #replace( HTMLEditFormat( catch.additional[key] ), chr(10),'<br>', 'all' )#
	</cfloop>
</cfif>
<cfif structKeyExists( catch, 'tagcontext' )>
	<cfset len=arrayLen( catch.tagcontext )>
	<cfif len>
Stacktrace:
The Error Occurred in
		<cfloop index="idx" from="1" to="#len#">
			<cfset tc = catch.tagcontext[ idx ]>
			<cfparam name="tc.codeprinthtml" default="">
			<cfif len( tc.codeprinthtml )>
				<cfset isFirst = ( idx == 1 )>
					#isFirst ? "<b>#tc.template#: line #tc.line#</b>" : "<b>called from</b> #tc.template#: line #tc.line#"#
					#tc.codeprinthtml#
			<cfelse>
				#idx == 1 ? "<b>#tc.template#: line #tc.line#</b>" : "<b>called from</b> #tc.template#: line #tc.line#"#
			</cfif>
		</cfloop>
	</cfif>
</cfif>
Java Stacktrace:
#replace( catch.stacktrace, chr(10), "<br><span style='margin-right: 1em;'>&nbsp;</span>", "all" )#
Timestamp:<cfset timestamp = now()>#LsDateFormat( timestamp, 'short' )# #LsTimeFormat( timestamp, 'long' )#
</cfoutput>
