component name="TestShell" extends="mxunit.framework.TestCase" {

	public void function testCommandHandler()  {
    	var baos = createObject("java","java.io.ByteArrayOutputStream").init();
    	var bain = createObject("java","java.io.ByteArrayInputStream").init("ls#chr(10)#".getBytes());
    	var printWriter = createObject("java","java.io.PrintWriter").init(baos);
		var shell = new cfml.cli.Shell(bain,printWriter);
		commandHandler = new cfml.cli.CommandHandler(shell);
		commandHandler.initCommands();
		commandHandler.runCommandline("ls");
		debug(baos.toString());

	}

	public void function testShell()  {
    	var baos = createObject("java","java.io.ByteArrayOutputStream").init();
    	var n = chr(10);
    	var line = "ls" &n& "exit" & n;
    	var inStream = createObject("java","java.io.ByteArrayInputStream").init(line.getBytes());
		var shell = new cfml.cli.Shell(inStream,baos);
		shell.run();
		debug(shell.unansi(baos.toString()));

	}

	public void function testHelp()  {
		var shell = new cfml.cli.Shell();
		var result = shell.help();
	}

	public void function testHTML2ANSI()  {
		var shell = new cfml.cli.Shell();
		var result = shell.HTML2ANSI("
		<b>some bold text</b>
		some non-bold text
		<b>some bold text</b>
		");
	}

	public void function testShellComplete()  {
    	var outputstream = createObject("java","java.io.ByteArrayOutputStream").init();
    	var t = chr(9);
    	var n = chr(10);
		var shell = new cfml.cli.Shell(outputStream=outputstream);

		shell.run("hel#t#");
		wee = shell.unansi(outputstream.toString());
		request.debug(wee);
		assertEquals("help",wee);
		outputstream.reset();

		shell.run("cfdistro #t#");
		wee = shell.unansi(outputstream.toString());
		assertTrue(find("war",wee));
		outputstream.reset();

		shell.run("cfdistro dep#t#");
		wee = shell.unansi(outputstream.toString());
		assertTrue(find("dependency",wee));
		outputstream.reset();

		shell.run("ls #t#");
		wee = shell.unansi(outputstream.toString());
		outputstream.reset();

		shell.run("ls#t#");
		wee = shell.unansi(outputstream.toString());
		outputstream.reset();

		shell.run("test#t#");
		wee = shell.unansi(outputstream.toString());
		outputstream.reset();

		shell.run("testplug ro#t# #n#");
		wee = shell.unansi(outputstream.toString());
		outputstream.reset();

		shell.run("testplug o#t#");
		wee = shell.unansi(outputstream.toString());
		outputstream.reset();

	}

	public void function testWindowsANSI()  {
		System = createObject("java", "java.lang.System");
		var ansiOut = createObject("java","org.fusesource.jansi.AnsiConsole").out;
        var printWriter = createObject("java","java.io.PrintWriter").init(
        		createObject("java","java.io.OutputStreamWriter").init(ansiOut,
        			// default to Cp850 encoding for Windows console output (ROO-439)
        			System.getProperty("jline.WindowsTerminal.output.encoding", "Cp850")));
    	var t = chr(9);
    	var n = chr(10);
		var shell = new cfml.cli.Shell(printWriter=printWriter);

		shell.run("hel#t#");
		ansiOut.close();
		wee = replace(ansiOut,chr(0027),"","all");
		debug(wee);

	}

}