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
 * @createTime 2016年2月27日
 * @tips 仅供学习与交流使用
 * @use 配置文件读取与分割字符串
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
