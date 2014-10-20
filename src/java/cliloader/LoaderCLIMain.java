package cliloader;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileDescriptor;
import java.io.FileOutputStream;
import java.io.BufferedInputStream;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.FilenameFilter;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.io.PrintWriter;
import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Arrays;
import java.util.Collection;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.LinkedList;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Properties;
import java.util.Set;
import java.util.Timer;
import java.util.TimerTask;
import java.util.jar.JarEntry;
import java.util.jar.JarInputStream;

import runwar.Start;

public class LoaderCLIMain {

	private static String LIB_ZIP_PATH = "libs.zip";
	private static String CFML_ZIP_PATH = "cfml.zip";
	private static String ENGINECONF_ZIP_PATH = "engine.zip";
	private static ClassLoader classLoader = Thread.currentThread().getContextClassLoader();
	private static Boolean debug = false;
	private static int exitCode = 0;
    private static final File thisJar = new File(LoaderCLIMain.class.getProtectionDomain().getCodeSource().getLocation().getPath());
	public static final Set<String> loggers = new HashSet<String>(Arrays.asList(new String[] {
			"RunwarLogger",
			"org.jboss.logging",
			"org.xnio.Xnio",
			"org.xnio.nio.NioXnio",
			"io.undertow.UndertowLogger"
	}));

	public static void main(String[] args) throws Throwable {
    	ArrayList<String> argList = new ArrayList(Arrays.asList(args));
		Properties props = new Properties();
		try {
	        props.load(classLoader.getSystemResourceAsStream("cliloader/cli.properties"));
	    } catch (IOException e) { e.printStackTrace(); }
		String name = props.getProperty("name") != null ? props.getProperty("name") : "railo";
		String NAME = name.toUpperCase();
		String version = props.getProperty("version") != null ? props.getProperty("version") : "0.0.0.0";
		Map<String,String> config=toMap(args);
		Boolean updateLibs = false;
		Boolean startServer = false;
		Boolean stopServer = false;
		Boolean background = false;
		File cli_home;
		String currentDir = System.getProperty("user.dir");
		Map<String, String> env = System.getenv();
		if (config.get(name+"_home") != null) {
			cli_home = new File(config.get(name+"_home"));
			args = removeElement(args,"-"+name+"_home");
		} else if (System.getProperty(NAME+"_HOME") != null) {
			cli_home = new File(System.getProperty(NAME+"_HOME"));
		} else if (env.get(NAME+"_HOME") != null) {
			cli_home = new File(env.get(NAME+"_HOME"));
		} else {
			String userHome = System.getProperty("user.home");
			if(userHome != null) {
				cli_home = new File(userHome + "/."+name+"/");
			} else {
				cli_home = new File(LoaderCLIMain.class.getProtectionDomain().getCodeSource().getLocation().getPath()).getParentFile();
			}
		}
		if(!cli_home.exists()) {
			System.out.println("Configuring "+name+" home: "+ cli_home + " (change with -"+name+"_home=/path/to/dir)");
			cli_home.mkdir();
		}
		//System.out.println(home_dir.getPath());
		File libDir=new File(cli_home,"lib").getCanonicalFile();
		
		// debug
		if(listContains(argList,"-debug")) {
			debug = true;
			listRemoveContaining(argList,"-debug");
			args = removeElement(args,"-debug");
		}
		String loglevel = debug ? "DEBUG" : "WARN" ;
		subvertLoggers(loglevel, loggers);

		// update/overwrite libs
		if(listContains(argList,"-update")) {
			System.out.println("updating "+name+" home");
			updateLibs = true;
			listRemoveContaining(argList,"-update");
			args = removeElement(args,"-update");
		}
		
		if(listContains(argList,"-stop")) {
			stopServer = true;
			background = false;
		}
		
		if(!updateLibs && (listContains(argList,"-?") || listContains(argList,"-help"))) {
			System.out.println(props.get("usage").toString().replace("/n",System.getProperty("line.separator").toString()));
			Thread.sleep(1000);
			System.exit(0);
		}
		
		// railo libs dir
		if(listContains(argList,"-lib")) {
			String strLibs=config.get("lib");
			libDir=new File(strLibs);
			args = removeElementThenAdd(args,"-lib=",null);
			listRemoveContaining(argList,"-lib");
		}

		if(listContains(argList,"-server")) {
			startServer=true;
		}

		if(listContains(argList,"-shell")) {
			startServer=false;
			args = removeElement(args,"-shell");
			listRemoveContaining(argList,"-shell");
		}

		if(debug) System.out.println("lib dir: " + libDir);
		
		// clean out any leftover pack files (an issue on windows)
		if(libDir.exists() && libDir.listFiles(new ExtFilter(".gz")).length > 0){
			for(File gz : libDir.listFiles(new ExtFilter(".gz"))) {
				try { gz.delete(); } catch (Exception e) {}
			}
		}

		if (!libDir.exists() || libDir.listFiles(new ExtFilter(".jar")).length < 2 
				|| updateLibs) {
			System.out.println("Library path: " + libDir);
			System.out.println("Initializing libraries -- this will only happen once, and takes a few seconds...");
			Util.unzipInteralZip(classLoader, LIB_ZIP_PATH, libDir, debug);
			Util.unzipInteralZip(classLoader, CFML_ZIP_PATH, new File(cli_home.getPath()+"/cfml"), debug);
			Util.unzipInteralZip(classLoader, ENGINECONF_ZIP_PATH, new File(cli_home.getPath()+"/engine"), debug);
			Util.copyInternalFile(classLoader, "resource/trayicon.png", new File(libDir,"trayicon.png"));
			System.out.println("");
			System.out.println("Libraries initialized");
			if(updateLibs && args.length == 0) {
				System.out.println("updated! ctrl-c now or wait a few seconds for exit..");
				System.exit(0);
			}
		}
		
        File[] children = libDir.listFiles(new ExtFilter(".jar"));
        if(children.length<2) {
        	libDir=new File(libDir,"lib");
        	 children = libDir.listFiles(new ExtFilter(".jar"));
        }
        
        URL[] urls = new URL[children.length];
        if(debug) System.out.println("Loading Jars");
        for(int i=0;i<children.length;i++){
        	urls[i]=children[i].toURI().toURL();
        	if(debug) System.out.println("- "+urls[i]);
        }
        //URLClassLoader cl = new URLClassLoader(urls,ClassLoader.getSystemClassLoader());
        //URLClassLoader cl = new URLClassLoader(urls,null);
        URLClassLoader cl = new URLClassLoader(urls,classLoader);
		//Thread.currentThread().setContextClassLoader(cl);
        InputStream originalIn = System.in;
        PrintStream originalOut = System.out;
//    	Thread shutdownHook = new Thread( "cli-shutdown-hook" ) { public void run() { cl.close(); } };
//      Runtime.getRuntime().addShutdownHook( shutdownHook );	
		File configServerDir=new File(libDir.getParentFile(),"engine/railo/");
		File configWebDir=new File(libDir.getParentFile(),"engine/railo/railo-web");
		System.setProperty("cfml.cli.home", cli_home.getAbsolutePath());
		System.setProperty("cfml.server.trayicon", libDir.getAbsolutePath() + "/trayicon.png");
		System.setProperty("cfml.server.dockicon", "");
        if(!startServer && !stopServer) {
        	System.setIn(new NonClosingInputStream(System.in));
    		final String SHELL_CFM = props.getProperty("shell") != null ? props.getProperty("shell") : "/cfml/cli/shell.cfm";
    		String uri = cli_home.getCanonicalPath() + SHELL_CFM;
        	if(debug) System.out.println("Running in CLI mode");
        	if(argList.size() > 1 && argList.contains("execute")) {
        		// bypass the shell for running pure CFML files
        		int executeIndex = argList.indexOf("execute");
        		File cfmlFile = new File(argList.get(executeIndex+1));
        		String filename = cfmlFile.getCanonicalPath();
    		    if(cfmlFile.exists()) {
    		        uri = cfmlFile.getCanonicalPath();
    		    }
    		    argList.remove(executeIndex+1);
    		    argList.remove(executeIndex);
    		    if(debug) System.out.println("Executing: "+uri);
        	} else if(argList.size() > 0 && new File(argList.get(0)).exists()) {
        		String filename = argList.get(0);
        		// this will force the shell to run the execute command
                if(filename.endsWith(".rs") || filename.endsWith(".boxr")) {
                    if(debug) System.out.println("Executing batch file: "+filename);
        			argList.add(0, "recipe");
        		} else {
            		File cfmlFile = new File(filename);
            		if(cfmlFile.exists()) {
            		    if(debug) System.out.println("Executing file: "+filename);
            			uri = cfmlFile.getCanonicalPath();
            		}
        		}
        	}

    		System.setProperty("cfml.cli.arguments",arrayToList(argList.toArray(new String[argList.size()])," "));
            Class<?> cli;
	        cli = cl.loadClass("railocli.CLIMain");
	        Method run = cli.getMethod("run",new Class[]{File.class,File.class,File.class,String.class,boolean.class});

	        // handle bash script
			FileReader namereader = new FileReader(new File(uri));
			BufferedReader in = new BufferedReader(namereader);
			String line = in.readLine();
			if(line != null && line.startsWith("#!")) {
				File tmpfile = new File(uri+".tmp");
				tmpfile.deleteOnExit();
				PrintWriter writer = new PrintWriter(tmpfile);
				while ((line = in.readLine()) != null) {
					//writer.println(line.replaceAll(oldstring,newstring));
					writer.println(line);
				}
				uri += ".tmp";
				writer.close();
			}
			in.close();

			try{
				File webroot=new File(getPathRoot(uri)).getCanonicalFile();
	        	run.invoke(null, webroot,configServerDir,configWebDir,uri,debug);
			} catch (Exception e) {
				exitCode = 1;
				e.getCause().printStackTrace();
			}
			cl.close();
/*			
			String osName = System.getProperties().getProperty("os.name");
  			if(osName != null && !osName.contains("indows")){
				final String ANSI_CLS = "\u001b[2J";
				final String ANSI_HOME = "\u001b[H";
				System.out.print(ANSI_CLS + ANSI_HOME);	        	
			}
*/
			System.out.flush();
			System.setOut(originalOut);
	        System.setIn(originalIn);
			System.exit(exitCode);
        } 
        else {
        	if(debug) System.out.println("Running in server mode");
    		//only used for server mode, cli root is /
    		File webRoot;
    		if(listContains(argList,"-webroot") && config.get("webroot") != null) {
				args = removeElement(args,"-webroot");
    			webRoot = new File(config.get("webroot")).getCanonicalFile();
    		} else {
    			if(currentDir != null) {
    				webRoot = new File(currentDir).getCanonicalFile();
    			} else {
    				webRoot = new File("./").getCanonicalFile();
    			}
    		}
			// background
			if(listContains(argList,"-background")) {
				background = true;
				args = removeElement(args,"-background");
			}
	        Class<?> runwar;
	        runwar = cl.loadClass("runwar.Start");
			String path = LoaderCLIMain.class.getProtectionDomain().getCodeSource().getLocation().getPath();
			//System.out.println("yum from:"+path);
			String decodedPath = java.net.URLDecoder.decode(path, "UTF-8");
			decodedPath = new File(decodedPath).getPath();

    		//args = removeElementThenAdd(args,"-server","-war "+webRoot.getPath()+" --background false --logdir " + libDir.getParent());
    		String[] argstr;
    		if(background) {
    			argstr= new String[] {
    					"-war",webRoot.getPath(),
    					"--railoserver",configServerDir.getAbsolutePath(),
    					"--railoweb",configWebDir.getAbsolutePath(),
    					"--background","true",
    					"--iconpath",libDir.getAbsolutePath() + "/trayicon.png",
    					"--libdir",libDir.getPath(),
    					"--processname",name
    					};
    		} else {
    			argstr= new String[] {
    					"-war",webRoot.getPath(),
    					"--railoserver",configServerDir.getAbsolutePath(),
    					"--railoweb",configWebDir.getAbsolutePath(),
    					"--iconpath",libDir.getAbsolutePath() + "/trayicon.png",
    					"--background","false",
    					"--processname",name
    					};
    		}
    		args = removeElementThenAdd(args,"-server",argstr);
        	if(debug) System.out.println("Args: " + arrayToList(args," "));
            Method main = runwar.getMethod("main",new Class[]{String[].class});
    		try{
            	main.invoke(null, new Object[]{args});
    		} catch (Exception e) {
    			exitCode = 1;
    			e.getCause().printStackTrace();
    		}
			cl.close();
        } 
	}

	private static void subvertLoggers(String level, Set<String> loggers) {
		System.setProperty("java.util.logging.ConsoleHandler.formatter", "java.util.logging.SimpleFormatter");
		System.setProperty("java.util.logging.SimpleFormatter.format", "%1$tY-%1$tm-%1$td %1$tH:%1$tM:%1$tS %4$s %2$s %5$s%6$s%n");
        java.util.logging.ConsoleHandler chandler = new java.util.logging.ConsoleHandler();
        if(level.trim().toUpperCase().equals("TRACE"))
        	level = "FINER";
        if(level.trim().toUpperCase().equals("WARN"))
        	level = "WARNING";
        if(level.trim().toUpperCase().equals("DEBUG"))
        	level = "FINEST";
        java.util.logging.Level LEVEL = java.util.logging.Level.parse(level);
        chandler.setLevel(LEVEL);
		java.util.logging.LogManager logManager = java.util.logging.LogManager.getLogManager();
		for(Enumeration<String> loggerNames = logManager.getLoggerNames(); loggerNames.hasMoreElements();){
	        String name = loggerNames.nextElement();
	        java.util.logging.Logger nextLogger = logManager.getLogger(name);
	        if(loggers.contains(name) && nextLogger != null) {
	        	nextLogger.setUseParentHandlers(false);
	        	nextLogger.setLevel(LEVEL);
	        	if(nextLogger.getHandlers() != null) {
	        		for(java.util.logging.Handler handler : nextLogger.getHandlers()) {
	        			nextLogger.removeHandler(handler);
	        		}
	        		nextLogger.addHandler(chandler);	        		
	        	}
	        }
	    }		
	}

	
	public static String[] removeElement(String[] input, String deleteMe) {
		final List<String> list =  new ArrayList<String>();
		Collections.addAll(list, input);
		for(String item: input) {
	        if(item.startsWith(deleteMe)) {
	        	list.remove(item);
	        }
		}
		input = list.toArray(new String[list.size()]);
		return input;
	}
	
	public static String[] removeElementThenAdd(String[] input, String deleteMe, String[] addList) {
	    List<String> result = new LinkedList<String>();
	    for(String item : input)
	        if(!item.startsWith(deleteMe))
	            result.add(item);

	    if(addList != null)
		    for(String item : addList)
		    		result.add(item);
	    
	    return result.toArray(input);
	}


	public static class ExtFilter implements FilenameFilter {
		private String ext;
		public ExtFilter(String extension) {
			ext = extension;
		}
		
		public boolean accept(File dir, String name) {
			return name.toLowerCase().endsWith(ext);
		}

	}
	
	public static String arrayToList(String[] s, String separator) {  
	       String result = "";  
	    if (s.length > 0) {  
	        result = s[0];     
	   for (int i=1; i<s.length; i++) {  
	            result = result + separator + s[i];  
	        }  
	    }  
	    return result;  
	}
	
	public static boolean listContains(ArrayList<String> argList, String text) {  
	    boolean found = false;
		for(String item : argList)
	        if(item.startsWith(text))
	            found = true;
		return found;
	}
	
	public static void listRemoveContaining(ArrayList<String> argList, String text) {
		for (Iterator<String> it = argList.iterator(); it.hasNext();) {
			String str = it.next();
			if (str.startsWith(text)) {
				it.remove();
			}
		}
	}
	
	private static Map<String, String> toMap(String[] args) {
		int index;
		Map<String, String> config=new HashMap<String, String>();
		String raw,key,value;
		if(args!=null)for(int i=0;i<args.length;i++){
			raw=args[i].trim();
			if(raw.length() == 0) continue;
			if(raw.startsWith("-"))raw=raw.substring(1).trim();
			index=raw.indexOf('=');
			if(index==-1) {
				key=raw;
				value="";
			}
			else {
				key=raw.substring(0,index).trim();
				value=raw.substring(index+1).trim();
			}
			config.put(key.toLowerCase(), value);
		}
		return config;
	}

	public static String getPathRoot(String string) {
		return string.replaceAll("^([^\\\\//]*?[\\\\//]).*?$", "$1");
	}

}
