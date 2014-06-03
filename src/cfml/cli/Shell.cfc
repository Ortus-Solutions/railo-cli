/**
 * CFML Shell
 **/
component output="false" {

	System = createObject("java", "java.lang.System");
    StringEscapeUtils = createObject("java","org.apache.commons.lang.StringEscapeUtils");
	keepRunning = true;
    reloadshell = false;
	script = "";
	lastline="";
	initialDirectory = System.getProperty("user.dir");
	pwd = initialDirectory;
	cr = System.getProperty("line.separator");

	/**
	 * constructor
	 * @inStram.hint input stream if running externally
	 * @printWriter.hint output if running externally
	 **/
	function init(inStream, printWriter) {
		if(isNull(printWriter)) {
			//new PrintWriter(OutputStreamWriter(System.out,System.getProperty("jline.WindowsTerminal.output.encoding",System.getProperty("file.encoding"))));
	    	reader = createObject("java","jline.console.ConsoleReader").init();
		} else {
			if(isNull(arguments.inStream)) {
		    	var FileDescriptor = createObject("java","java.io.FileDescriptor").init();
		    	inStream = createObject("java","java.io.FileInputStream").init(FileDescriptor.in);
			}
	    	reader = createObject("java","jline.console.ConsoleReader").init(inStream,printWriter);
		}
    	variables.homedir = env("user.home") & "/.railo";
    	variables.tempdir = variables.homedir & "/temp";
    	variables.profiledir = variables.homedir & "/profile";
        variables.hasInput = false;
		if(!directoryExists(profiledir)) {
			directoryCreate(profiledir,true);
		}
		variables.shellPrompt = ansi("yellow","cfml> ");
		variables.commandHandler = new CommandHandler(this);
		var historyFile = createObject("java", "java.io.File").init(homedir&"/.history");
		var history = createObject("java", "jline.console.history.FileHistory").init(historyFile);
		reader.setHistory(history);
    	return this;
	}

	/**
	 * Run CommandLine
	 **/
	function runCommandLine(String line) {
		var result = commandHandler.runCommandLine(line);
		result = isNull(result) ? "" : print(result);
	}

	/**
	 * returns the console reader
	 **/
	function getReader() {
    	return reader;
	}

	/**
	 * sets exit flag
	 **/
	function exit() {
    	keepRunning = false;
		return "Peace out!";
	}

	/**
	 * shell version
	 **/
	function version() {
		var versionFile = getDirectoryFromPath(getMetadata(this).path)&"/version";
		var version = "0.0.0";
		if(fileExists(versionFile)) {
			version = fileRead(versionFile);
		}
		return version;
	}

	/**
	 * sets reload flag, relaoded from shell.cfm
	 * @clear.hint clears the screen after reload
 	 **/
	function reload(Boolean clear=true) {
		if(clear) {
			reader.clearScreen();
		}
		reloadshell = true;
    	keepRunning = false;
	}

	/**
	 * returns the current console text
 	 **/
	function getText() {
    	return reader.getCursorBuffer().toString();
	}

	/**
	 * sets prompt
	 * @text.hint prompt text to set
 	 **/
	function setPrompt(text="") {
		if(text eq "") {
			text = variables.shellPrompt;
		} else {
			variables.shellPrompt = text;
		}
		reader.setPrompt(variables.shellPrompt);
		return "set prompt";
	}

	/**
	 * gets prompt
 	 **/
	function getPrompt() {
		return variables.shellPrompt;
	}

	/**
	 * ask the user a question and wait for response
	 * @message.hint message to prompt the user with
 	 **/
	function ask(message) {
		var input = "";
		try {
			input = reader.readLine(message);
		} catch (any e) {
			printError(e);
		}
		reader.setPrompt(variables.shellPrompt);
		return input;
	}

	/**
	 * clears the console
 	 **/
	function clearScreen() {
		reader.clearScreen();
	}

	/**
	 * Converts HTML into plain text
	 * @html.hint HTML to convert
  	 **/
	function unescapeHTML(required html) {
    	var text = StringEscapeUtils.unescapeHTML(html);
    	text = replace(text,"<" & "br" & ">","","all");
       	return text;
	}

	/**
	 * Converts HTML into ANSI text
	 * @html.hint HTML to convert
  	 **/
	function HTML2ANSI(required html) {
    	var text = replace(unescapeHTML(html),"<" & "br" & ">","","all");
    	var t="b";
    	if(len(trim(text)) == 0) {
    		return "";
    	}
    	var matches = REMatch('(?i)<#t#[^>]*>(.+?)</#t#>', text);
    	text = ansifyHTML(text,"b","bold");
    	text = ansifyHTML(text,"em","underline");
       	return text;
	}

	/**
	 * Converts HTML matches into ANSI text
	 * @text.hint HTML to convert
	 * @tag.hint HTML tag name to replace
	 * @ansiCode.hint ANSI code to replace tag with
  	 **/
	private function ansifyHTML(text,tag,ansiCode) {
    	var t=tag;
    	var matches = REMatch('(?i)<#t#[^>]*>(.+?)</#t#>', text);
    	for(var match in matches) {
    		var boldtext = ansi(ansiCode,reReplaceNoCase(match,"<#t#[^>]*>(.+?)</#t#>","\1"));
    		text = replace(text,match,boldtext,"one");
    	}
    	return text;
	}

	/**
	 * returns the current directory
  	 **/
	function pwd() {
    	return pwd;
	}

	/**
	 * sets the shell home directory
	 * @directory.hint directory to use
  	 **/
	function setHomeDir(required directory) {
		variables.homedir = directory;
		setTempDir(variables.homedir & "/temp");
		return variables.homedir;
	}

	/**
	 * returns the shell home directory
  	 **/
	function getHomeDir() {
		return variables.homedir;
	}

	/**
	 * returns the profile directory
  	 **/
	function getProfileDir() {
		return variables.profiledir;
	}

	/**
	 * returns the shell artifacts directory
  	 **/
	function getArtifactsDir() {
		return getHomeDir() & "/artifacts";
	}

	/**
	 * sets and renews temp directory
	 * @directory.hint directory to use
  	 **/
	function setTempDir(required directory) {
        lock name="clearTempLock" timeout="3" {
        	try {
		        var clearTemp = directoryExists(directory) ? directoryDelete(directory,true) : "";
		        directoryCreate( directory );
		        variables.tempdir = directory;
        	} catch (any e) {
        		printError(e);
        	}
        }
    	return variables.tempdir;
	}

	/**
	 * returns the shell temp directory
  	 **/
	function getTempDir() {
		return variables.tempdir;
	}

	/**
	 * returns the enviroment property
  	 **/
	function env(required name) {
		var value = System.getProperty(name);
    	return isNull(value) ? "" : value;
	}

	/**
	 * changes the current directory
	 * @directory.hint directory to CD to
  	 **/
	function cd(directory="") {
		directory = replace(directory,"\","/","all");
		if(directory=="") {
			pwd = initialDirectory;
		} else if(directory=="."||directory=="./") {
			// do nothing
		} else if(directoryExists(directory)) {
	    	pwd = directory;
		} else {
			return "cd: #directory#: No such file or directory";
		}
		return pwd;
	}

	/**
	 * Adds ANSI attributes to string
	 * @attribute.hint list of ANSI codes to apply
	 * @string.hint string to apply ANSI to
  	 **/
	function ansi(required attribute, required string) {
		var textAttributes =
		{"off":0,
		 "none":0,
		 "bold":1,
		 "underscore":4,
		 "blink":5,
		 "reverse":7,
		 "concealed":8,
		 "black":30,
		 "red":31,
		 "green":32,
		 "yellow":33,
		 "blue":34,
		 "magenta":35,
		 "cyan":36,
		 "white":37,
		 "black_back":40,
		 "red_back":41,
		 "green_back":42,
		 "yellow_back":43,
		 "blue_back":44,
		 "magenta_back":45,
		 "cyan_back":46,
		 "white_back":47,
		}
		var ansiString = "";
		for(var attrib in listToArray(attribute)) {
			ansiString &= chr(27) & "[" & textAttributes[attrib] & "m";
		}
		ansiString &= string & chr(27) & "[" & textAttributes["off"] & "m";
    	return ansiString;
	}

	/**
	 * Removes ANSI attributes from string
	 * @string.hint string to remove ANSI from
  	 **/
	function unansi(required string) {
		var st = createObject("java","org.fusesource.jansi.AnsiString").init(string);
		return st.getPlain();
//		string = string.replaceAll("\u001B\[[;\d]*m","").replaceAll("\u001B\[\d\w","");
//		return string;
	}

	/**
	 * prints string to console
	 * @string.hint string to print (handles complex objects)
  	 **/
	function print(required string) {
		if(!isSimpleValue(string)) {
			if(isArray(string)) {
				return reader.printColumns(string);
			}
			string = formatJson(serializeJSON(string));
		}
    	return reader.print(string);
	}

	/**
	 * prints string to console with newline
	 * @string.hint string to print (handles complex objects)
  	 **/
	function println(any string) {
		string = isNull(string) ? "" : string ;
    	print(string);
    	print(cr);
	}

	public function formatJson(json) {
		var retval = '';
		var str = json;
	    var pos = 0;
	    var strLen = str.length();
		var indentStr = '    ';
	    var newLine = cr;
		var char = '';

		for (var i=0; i<strLen; i++) {
			char = str.substring(i,i+1);
			if (char == '}' || char == ']') {
				retval &= newLine;
				pos = pos - 1;
				for (var j=0; j<pos; j++) {
					retval &= indentStr;
				}
			}
			retval &= char;
			if (char == '{' || char == '[' || char == ',') {
				retval &= newLine;
				if (char == '{' || char == '[') {
					pos = pos + 1;
				}
				for (var k=0; k<pos; k++) {
					retval &= indentStr;
				}
			}
		}
		return retval;
	}

	/**
	 * runs the shell thread until exit flag is set
	 * @input.hint command line to run if running externally
  	 **/
    function run(input="") {
        var mask = "*";
        var trigger = "su";
        reloadshell = false;

		try{
	        if (input != "") {
	        	input &= chr(10);
	        	var inStream = createObject("java","java.io.ByteArrayInputStream").init(input.getBytes());
	        	reader.setInput(inStream);
	        }
	        reader.setBellEnabled(false);
	        //reader.setDebug(new PrintWriter(new FileWriter("writer.debug", true)));

	        var line ="";
	        keepRunning = true;
			reader.setPrompt(shellPrompt);
			// set and recreate temp dir
			setTempDir(variables.tempdir);
	        while (keepRunning) {
				if(input != "") {
					keepRunning = false;
				}
				reader.println();
				try {
		        	line = reader.readLine();
		        	variables.lastline=line;
				} catch (any er) {
					printError(er);
					// reload();
					continue;
				}
				if(trim(line) == "reload") {
					reload();
					continue;
				}
	            //reader.print("======>" & line);
	            // If we input the special word then we will mask
	            // the next line.
	            if ((!isNull(trigger)) && (line.compareTo(trigger) == 0)) {
	                line = reader.readLine("password> ", javacast("char",mask));
	            }
				var args = rematch("'.*?'|"".*?""|\S+",line);
				if(args.size() == 0 || len(trim(line))==0) continue;
				try{
					runCommandLine(line);
				} catch (any e) { printError(e); }
	        }

		} catch (any e) {
			printError(e);
		}
		if(!reloadshell) {

		}
		return reloadshell;
    }


	/**
	 * display help information
	 * @namespace.hint namespace (or namespaceless command) to get help for
 	 * @command.hint command to get help for
 	 **/
	function help(String namespace="", String command="")  {
		return commandHandler.help(namespace,command);
	}

	/**
	 * call a namespace command
	 * @namespace.hint namespace (empty string for default)
 	 * @command.hint command name
 	 * @args.hint arguments
 	 **/
	function callCommand(String namespace="", String command="", args)  {
		return commandHandler.callCommand(namespace,command,args);
	}

	/**
	 * print an error to the console
	 * @err.hint Error object to print (only message is required)
  	 **/
	function printError(required err, fatal=false) {
//		filewrite("/tmp/fart.txt",formatJSON(serializeJSON(err)));
		if(fatal) keepRunning = false;
		reader.print(ansi("red","ERROR: ") & HTML2ANSI(err.message));
		if (err.type == "command.exception" ) {
			if(structKeyExists(err,"extendedInfo") && err.extendedInfo != "") {
				var column = val(listLast(err.extendedInfo,":"))+1;
				reader.println();
				reader.println(variables.lastline);
				reader.print(createObject("java","java.util.Formatter").format("%1$" & column & "s",["^"]));
			}
		} else if (structKeyExists( err, 'tagcontext' )) {
			reader.println();
			reader.print(ansi("red"," #err.type# error in: "));
			var lines=arrayLen( err.tagcontext );
			if (lines != 0) {
				for(idx=1; idx<=lines; idx++) {
					tc = err.tagcontext[ idx ];
					if (len( tc.codeprinthtml )) {
						isFirst = ( idx == 1 );
						isFirst ? reader.print(ansi("red","#tc.template#: line #tc.line#")) : reader.print(ansi("magenta","#ansi('bold','called from ')# #tc.template#: line #tc.line#"));
						reader.println();
						reader.print(ansi("blue",HTML2ANSI(tc.codeprinthtml)));
					}
				}
			}
		}
		reader.println();
	}

}