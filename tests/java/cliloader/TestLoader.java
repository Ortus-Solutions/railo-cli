package cliloader;

import static org.junit.Assert.*;

import org.junit.After;
import org.junit.AfterClass;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Test;

public class TestLoader {

	private LoaderCLIMain cliLoader;

	@Before
	public void setUp() throws Exception {
		cliLoader = new LoaderCLIMain();
	}

	@After
	public void tearDown() throws Exception {
	}

	@SuppressWarnings("static-access")
	@Test
	public final void testGetPathRoot() {
		String root = cliLoader.getPathRoot("D:\\Users\\someone\\home");
		assertTrue(root.equals("D:\\"));
		root = cliLoader.getPathRoot("C:/Users/someone/home");
		assertTrue(root.equals("C:/"));
		root = cliLoader.getPathRoot("D:/Users/someone/home");
		assertTrue(root.equals("D:/"));
		root = cliLoader.getPathRoot("D:\\Users\\someone\\home");
		assertTrue(root.equals("D:\\"));
		root = cliLoader.getPathRoot("/wee/hoo");
		assertTrue(root.equals("/"));
		root = cliLoader.getPathRoot("/");
		assertTrue(root.equals("/"));
	}

}
