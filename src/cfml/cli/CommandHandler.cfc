/**
 * Command handler
 * @author Denny Valliant
 **/
component output="false" persistent="false" {

	commands = {};
	commandAliases = {};
	namespaceHelp = {};
	thisdir = getDirectoryFromPath(getMetadata(this).path);
	java = {
		System : createObject("java", "java.lang.System")
		,StringReader : createObject("java","java.io.StringReader")
		,StreamTokenizer : createObject("java","java.io.StreamTokenizer")
	}
	cr = java.System.getProperty("line.separator");

	/**
	 * constructor
	 * @shell.hint shell this command handler is attached to
	 **/
	function init(required shell) {
		variables.shell = shell;
		reader = shell.getReader();
        var completors = createObject("java","java.util.LinkedList");
		initCommands();
		commandGrammar = new commandgrammar.CommandGrammar();
		commandGrammar.setCommands(getCommands());
		var completor = createDynamicProxy(new Completor(this), ["jline.console.completer.Completer"]);
        reader.addCompleter(completor);
		return this;
	}

	/**
	 * initialize the commands
	 **/
	function initCommands() {
		var varDirs = DirectoryList(thisdir & "/command", false, "name");
		for(var dir in varDirs){
			if(listLast(dir,".") eq "cfc") {
				loadCommands("","command.#listFirst(dir,'.')#");
			} else {
				if(fileExists(thisdir & "/command/#dir#/#dir#.cfc")) {
					loadCommands(dir,"command.#dir#.#dir#");
				}
			}
		}
	}

	/**
	 * load commands into a namespace from a cfc
	 * @namespace.hint namespace these commands belong in
	 * @cfc.hint cfc to read for commands
	 **/
	function loadCommands(namespace,cfc) {
		var cfc = createObject(cfc).init(shell);
		var cfcMeta = getMetadata(cfc);
		for(var fun in cfcMeta.functions) {
			if(fun.name != "init" && fun.access != "private") {
				var commandname = isNull(fun["command.name"]) ? fun.name : trim(fun["command.name"]);
				for(var param in fun.parameters) {
					if(isNull(param.hint)) {
						param.hint = "No help available";
					}
				}
				commands[namespace][commandname].parameters = fun.parameters;
				commands[namespace][commandname].functionName = fun.name;
				commands[namespace][commandname].cfc = cfc;
				commands[namespace][commandname].hint = !isNull(fun.hint) ? fun.hint : "";
				var aliases = isNull(fun["command.aliases"]) ? [] : listToArray(fun["command.aliases"]);
				for(var alias in aliases) {
					commands[namespace][trim(alias)] = commands[namespace][commandname];
				}
			}
		}
		if(namespace != "") {
			namespaceHelp[namespace] = !isNull(cfcMeta.hint) ? cfcMeta.hint : "";
		}
	}

	/**
	 * get help information
	 * @namespace.hint namespace (or namespaceless command) to get help for
 	 * @command.hint command to get help for
 	 **/
	function help(String namespace="", String command="")  {
		if(namespace != "" && command == "") {
			if(!isNull(commands[""][namespace])) {
				command = namespace;
				namespace = "";
			} else if(!isNull(commandAliases[""][namespace])) {
				command = commandAliases[""][namespace];
				namespace = "";
			} else if (isNull(commands[namespace])) {
				shell.printError({message:"No help found for #namespace#"});
				return "";
			}
		}
		var result = shell.ansi("green","HELP #namespace# [command]") & cr;
		if(namespace == "" && command == "") {
			for(var commandName in commands[""]) {
				var helpText = commands[""][commandName].hint;
				result &= chr(9) & shell.ansi("cyan",commandName) & " : " & helpText & cr;
			}
			for(var ns in namespaceHelp) {
				var helpText = namespaceHelp[ns];
				result &= chr(9) & shell.ansi("black,cyan_back",ns) & " : " & helpText & cr;
			}
		} else {
			if(!isNull(commands[namespace][command])) {
				result &= getCommandHelp(namespace,command);
			} else if (!isNull(commands[namespace])){
				var helpText = namespaceHelp[namespace];
				result &= chr(9) & shell.ansi("cyan",namespace) & " : " & helpText & cr;
				for(var commandName in commands[namespace]) {
					var helpText = commands[namespace][commandName].hint;
					result &= chr(9) & shell.ansi("cyan",commandName) & " : " & helpText & cr;
				}
			} else {
				shell.printError({message:"No help found for #namespace# #command#"});
				return "";
			}
		}
		return result;
	}

	/**
	 * get command help information
	 * @namespace.hint namespace (or namespaceless command) to get help for
 	 * @command.hint command to get help for
 	 **/
	private function getCommandHelp(String namespace="", String command="")  {
		var result ="";
		var metadata = commands[namespace][command];
		result &= chr(9) & shell.ansi("cyan",command) & " : " & metadata.hint & cr;
		result &= chr(9) & shell.ansi("magenta","Arguments") & cr;
		for(var param in metadata.parameters) {
			result &= chr(9);
			if(param.required)
				result &= shell.ansi("red","required ");
			result &= param.type & " ";
			result &= shell.ansi("magenta",param.name)
			if(!isNull(param.default))
				result &= "=" & param.default & " ";
			if(!isNull(param.hint))
				result &= " (#param.hint#)";
		 	result &= cr;
		}
		return result;
	}

	/**
	 * return the shell
 	 **/
	function getShell() {
		return variables.shell;
	}

	/**
	 * return the shell
 	 **/
	function getParser() {
		return variables.commandGrammar;
	}

	/**
	 * run a command line
	 * @line.hint line to run
 	 **/
	function runCommandline(line) {
		var parsed = parseCommandline(line);
		if(isNull(commands[parsed.namespace][parsed.command])) {
			throw(type="command.exception",message:"'#parsed.namespace# #parsed.command#' is unknown.  Did you mean one of these: #structKeyList(commands[parsed.namespace])#?");
		}
		return callCommand(parsed.namespace, parsed.command, parsed.args);
	}

	/**
	 * parse a command line
	 * @line.hint line to run
 	 **/
	function parseCommandline(line) {
		var retStruct = {"namespace":"", "command":"", "args":[]};
		var parsed = getParser().parse(line);
		var commandLine = parsed.tree;
		var namespace = isNull(commandLine.namespace()) ? "" : commandLine.namespace().getText();
		var command = commandLine.command().commandName().getText();
		var args = commandLine.command().arguments().argument();
		if(command == "<missing commandname>") {
			command = namespace == "" ? line : trim(line.replace(namespace,""));
			command = command == "" ? command : "Unknown command '#command#'! ";
			retStruct.command = command;
			retStruct.namespace = namespace;
			return retStruct;
		}
		if(arrayLen(parsed.messages)) {
			var lastMessage = parsed.messages[arrayLen(parsed.messages)];
			var expected = lastMessage.parse.tree != ""
					? "expected " & lastMessage.parse.tree
					: lastMessage.message ;
			throw(type="command.exception",
				message=expected,
				extendedInfo=1&":"&lastMessage.offendingSymbol.startIndex);
		}
		if(isNull(commands[namespace][command])) {
			throw(type="command.exception",message:"'#namespace# #command#' is unknown.  Did you mean one of these: #structKeyList(commands[namespace])#?");
		}
		var unnamedArgs = [];
		var namedArgs = {};
		var requiredParams = [];
		for(var param in commands[namespace][command].parameters) {
        	if(param.required) {
				arrayAppend(requiredParams,param);
        	}
		}
       	for(var arg in args) {
     		var value = unescapeString(arg.value().getText());
       		if(!isNull(arg.argumentName())) {
       			var argName = arg.argumentName().getText();
        		namedArgs[argName] = value;
      			if(arrayContains(requiredParams,argName)) {
        			arrayDelete(requiredParams,argName);
      			}
       		} else {
 				arrayAppend(unnamedArgs,value);
       		}
       	}
       	for(var x = arrayLen(requiredParams); x gt arrayLen(args); x--) {
       		var arg = shell.ask("Enter #requiredParams[x].name# (#requiredParams[x].hint#) : ");
			arrayAppend(unnamedArgs,arg.value().getText());
       	}
		if(len(StructKeyList(namedArgs))) {
			retstruct = {"namespace":namespace, "command": command, "args": namedArgs};
		} else {
			retStruct = {"namespace":namespace, "command": command, "args": unnamedArgs};
		}
		return retStruct;
	}

	/**
	 * unescape a string literal, so quotes and newlines'n stuff are correct
 	 **/
	function unescapeString(required stringLiteral) {
		if(left(stringLiteral,1)=='"' || left(stringLiteral,1)=="'") {
			var st = java.StreamTokenizer.init(java.StringReader.init(stringLiteral));
			st.nextToken();
			stringLiteral = isNull(st.sval) ? stringLiteral : st.sval ;
		}
		return stringLiteral ;
	}

	/**
	 * call a command
 	 **/
	function callCommand(namespace, command, args) {
		var functionName = commands[namespace][command].functionName;
		var runCFC = commands[namespace][command].cfc;
		args = isNull(args) ? [] : args;
		if(isArray(args) && args.size()) {
			return runCFC[functionName](argumentCollection=args);
		} else if (isStruct(args)) {
			return runCFC[functionName](argumentCollection=args);
		} else {
			return runCFC[functionName]();
		}
	}

	/**
	 * return a list of base commands (includes namespaces)
 	 **/
	function listCommands() {
		return listAppend(structKeyList(commands[""]),structKeyList(commands));
	}

	/**
	 * return the namespaced command structure
 	 **/
	function getCommands() {
		return commands;
	}

}
