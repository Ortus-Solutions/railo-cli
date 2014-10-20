component name="TestShell" extends="mxunit.framework.TestCase" {

	workdir = expandPath("/tests/work");
	homedir = workdir & "/home";

	public void function beforeTests()  {
		shell = new cfml.cli.Shell();
		directoryExists(workdir) ? directoryDelete(workdir,true) : "";
		directoryCreate(workdir);
		directoryCreate(homedir);
		variables.cli = new cfml.cli.command.cli(shell);
	}

	public void function testCat()  {
		assertTrue(shell.getHomeDir() == homedir);
		assertTrue(shell.getTempDir() == homedir & "/temp");
		var result = cli.cat(getMetadata(this).path);
	}

}