/**
 * @File Config.java
 * @Package tools
 */
package net.ruter.tools;

import java.io.IOException;
import java.util.Properties;
import java.util.StringTokenizer;

/**
 * @author Ruter
 * @createTime Feb 7, 2016 7:17:59 PM
 */
public class Config {
	public String[] split(String res,String sp){
		if(res == null || res.equals("")) {
			return null;
		}
		StringTokenizer token = new StringTokenizer(res, sp);
		String[] s = new String[token.countTokens()];
		int T = 0;
		while(token.hasMoreTokens()){
			s[T] = token.nextToken();
			T++;
		}
		return s;
	}
	public String getConfig(String propertyName){
		try {
			Properties properties = new Properties();
			properties.load(this.getClass().getClassLoader().getResourceAsStream("config.properties"));
			if(properties.containsKey(propertyName)){
				return properties.getProperty(propertyName);
			}
		} catch (IOException e) {
			e.printStackTrace();
		}
		return "0";
	}
}
