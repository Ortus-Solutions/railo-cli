package cliloader;

import java.io.*;
import java.net.URL;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.util.Timer;
import java.util.TimerTask;
import java.util.jar.*;
import java.util.zip.GZIPInputStream;

public class Util {

	private static final int KB = 1024;

	public static void unzipInteralZip(ClassLoader classLoader, String resourcePath, File libDir, boolean debug) {
		if (debug)
			System.out.println("Extracting " + resourcePath);
		libDir.mkdir();
		URL resource = classLoader.getResource(resourcePath);
		if (resource == null) {
			System.err.println("Could not find the " + resourcePath + " on classpath!");
			System.exit(1);
		}
		class PrintDot extends TimerTask {
			public void run() {
				System.out.print(".");
			}
		}
		Timer timer = new Timer();
		PrintDot task = new PrintDot();
		timer.schedule(task, 0, 2000);

		try {

			BufferedInputStream bis = new BufferedInputStream(resource.openStream());
			JarInputStream jis = new JarInputStream(bis);
			JarEntry je = null;
			while ((je = jis.getNextJarEntry()) != null) {
				java.io.File f = new java.io.File(libDir.toString() + java.io.File.separator + je.getName());
				if (je.isDirectory()) {
					f.mkdir();
					continue;
				}
				File parentDir = new File(f.getParent());
				if (!parentDir.exists()) {
					parentDir.mkdir();
				}
				writeStreamTo(jis, new FileOutputStream(f), 8 * KB);
				if (f.getPath().endsWith("pack.gz")) {
					unpack(f);
					f.delete();
				}
			}

		} catch (Exception exc) {
			task.cancel();
			exc.printStackTrace();
		}
		task.cancel();

	}
	
	public static void copyInternalFile(ClassLoader classLoader, String resourcePath, File dest) {
		URL resource = classLoader.getResource(resourcePath);
		try {
			BufferedInputStream bis = new BufferedInputStream(resource.openStream());
			FileOutputStream output = new FileOutputStream(dest);
			writeStreamTo(bis, output, 8 * KB);
			output.close();
		} catch (FileNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
        
	}

	public static void unpack(File inFile) {

		JarOutputStream out = null;
		InputStream in = null;
		String inName = inFile.getPath();
		String outName;

		if (inName.endsWith(".pack.gz")) {
			outName = inName.substring(0, inName.length() - 8);
		} else if (inName.endsWith(".pack")) {
			outName = inName.substring(0, inName.length() - 5);
		} else {
			outName = inName + ".unpacked";
		}
		try {
			Pack200.Unpacker unpacker = Pack200.newUnpacker();
			out = new JarOutputStream(new FileOutputStream(outName));
			in = new FileInputStream(inName);
			if (inName.endsWith(".gz"))
				in = new GZIPInputStream(in);
			unpacker.unpack(in, out);
		} catch (IOException ex) {
			ex.printStackTrace();
		} finally {
			if (in != null) {
				try { in.close();} catch (IOException ex) {
					System.err.println("Error closing file: " + ex.getMessage());
				}
			}
			if (out != null) {
				try { out.flush(); out.close(); } catch (IOException ex) {
					System.err.println("Error closing file: " + ex.getMessage());
				}
			}
		}
	}

	public static int writeStreamTo(final InputStream input, final OutputStream output, int bufferSize)
			throws IOException {
		int available = Math.min(input.available(), 256 * KB);
		byte[] buffer = new byte[Math.max(bufferSize, available)];
		int answer = 0;
		int count = input.read(buffer);
		while (count >= 0) {
			output.write(buffer, 0, count);
			answer += count;
			count = input.read(buffer);
		}
		return answer;
	}

	public static void copyFile(File source, File dest) throws IOException {
	  FileInputStream fi = new FileInputStream(source);
	  FileChannel fic = fi.getChannel();
	  MappedByteBuffer mbuf = fic.map(
	    FileChannel.MapMode.READ_ONLY, 0, source.length());
	  fic.close();
	  fi.close();
	  FileOutputStream fo = new FileOutputStream(dest);
	  FileChannel foc = fo.getChannel();
	  foc.write(mbuf);
	  foc.close();
	  fo.close();
	}
}
