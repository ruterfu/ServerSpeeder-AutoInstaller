/**
 * @File Lic.java
 * @Package net.ruter.servlet
 */


package net.ruter.servlet;

import java.io.IOException;
import java.io.OutputStream;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.StringTokenizer;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import net.ruter.tools.Config;

/**
 * @author Ruter
 * @createTime 2016年2月27日
 * @tips 仅供学习与交流使用
 * @use lic生成
 */
@WebServlet("/regenspeeder/lic")
public class Lic extends HttpServlet {
	private static final long serialVersionUID = 1L;

	public Lic() {
		super();
	}
	/**
	 * apx**.lic 在这里生成
	 * install.sh会带2mac=***请求这个servlet, servlet会根据mac地址来生成一个新的license,并让instlal.sh进行下载
	 */
	protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		String mac = request.getParameter("mac"); // 获取mac地址
		String expires = request.getParameter("expires"); // 获取到期时间
		String bandWidth = request.getParameter("bandwidth"); // 注意此处为12M为12Mbps
		func(mac, expires, bandWidth, response); // 方法调用
	}

	protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		doGet(request, response);
	}
	
	/**
	 * 主方法
	 * @param mac mac地址,不能为空
	 * @param exp 到期时间 可为空
	 * @param bandWidth 带宽,可为空
	 * @param resp HttpServletResponse,便于使用文件流输出
	 * @throws IOException
	 */
	public void func(String mac, String exp, String bandWidth, HttpServletResponse resp) throws IOException {
		Config config = new Config(); // 获取配置文件
		String expires = null; // 默认的过期为null
		if(exp == null || exp.length() == 0){ // 如果未传入到期日
			expires = config.getConfig("serverspeederexpire"); // 获取配置文件中的到期日子
		}else{
			expires = parseDate(exp); // 传入则使用传入的时间
		}
		boolean error = false;
		String msg = null;
		// 这就是apx.lic文件的byte数据,直接输出这个流数据会看到序列号为00000和到期日期为0000-00-00且带宽为0(部分显示unlimited)的文件
		byte[] b = {-78, 38, -68, 39, 78, 34, 15, 83, -30, 45, -122, 58, 30, -55, 19, -34, -90, -106, 27, -48, 70, -48, 52, -24, -120, 24, -26, -115, 38, 13, 120, 19, -32, -76, 34, 93, 59, 17, -32, 11, 80, 97, 4, 86, 103, -63, 42, -12, -104, 41, -110, -85, -122, -18, 122, 79, -124, -63, -17, -125, 2, 10, 26, -36, -46, 63, 31, -6, 105, 62, 93, -44, -61, 24, -88, -118, -91, 63, 31, 24, -56, 28, -77, -76, 4, -22, -74, -97, 89, -103, 63, -65, 98, -67, 55, 58, 0, 64, -6, 67, -50, -93, -12, 39, 54, -57, 67, -29, -93, 102, 68, 81, 19, -20, -9, 66, 5, -28, 10, -13, 44, -77, 12, 83, 66, -52, 94, -67, -104, 31, 126, 2, -87, 50, 111, 56, 35, -24, 48, 78, 77, 32, -7, 66, -14, 11, -33, -66, -82, -17, -8, 67};
		long[] speedAdding = null;
		if (bandWidth == null || bandWidth.equals("")) { // 如果没传入带宽,则使用配置文件里面的宽带
			speedAdding = parseSpeed(config.getConfig("bandWidth")); // 进行带宽格式化,例如将1M格式化城1024k
		} else {
			speedAdding = parseSpeed(bandWidth); // 如果传入带宽,则使用传入带宽值
		}

		String fileName = null;
		if(mac == null || mac.indexOf(":") == -1 || config.split(mac, ":").length!= 6) { // mac地址要求有:,且以:为分隔符后有6位长度
			error = true;
			msg = "Mac address is not corrent";
		}else if(expires == null){ // 如果时间格式化错误
			error = true;
			msg = "parameter expires is not corrent,accepted format: YYYY-MM-DD or YYYYMMDD";
		} else if(speedAdding == null) { // 如果带宽不符合规则
			error = true;
			msg = "parameter bandwidth too large or not current, accepted format: 10M 20M 100M 1G MAX bandWidth is 4200G etc....";
		} else{
			String data = calSerialKey(mac); // 计算lic中序列号
			fileName = "apx-"+ expires +".lic"; // 文件名定义
			try {
				// 修改带宽
				for (int i = 0; i < 4; i++) {
					byte tmp = (byte) speedAdding[i];
					b[104 + i] = (byte) (b[104 + i] + tmp);
				}

				for(int i = 0 ; i < data.length() ; i++) {
					char c = (char) (data.charAt(i) - '0');
					int offset = c;
					// 从64位开始为license信息,为什么我会知道,是因为我凑了一个下午凑出这个位置来的
					b[64 + i] = (byte) (b[64 + i] + (byte)offset);
				}

				// 写入到期时间
				StringTokenizer st = new StringTokenizer(expires, "-");
				int T = 0;
				int[] ymdSp = new int[3];
				while(st.hasMoreTokens()) {
					ymdSp[T] = Integer.parseInt(st.nextToken());
					T++;
				}
				ymdSp[0] = ymdSp[0] - 139;
				int divide = ymdSp[0] / 256;
				b[97] = (byte) (b[97] + (byte) divide);
				int latest = ymdSp[0] - 256 * divide;
				b[96] = (byte) (b[96] + (byte) latest);
				b[98] = (byte) (b[98] + (byte) ymdSp[1]);
				if(ymdSp[1] > 5) {
					ymdSp[2] += 1;
				}
				b[99] = (byte) (b[99] + (byte) ymdSp[2]);
				error = false;

			} catch (Exception e) {
				error = true;
				msg = "Unknown Exception";
				e.printStackTrace();
			}
		}
		if(error){
			resp.getWriter().print(msg);
		}else{
			// 文件流输出
			resp.setContentLength(b.length);
			resp.setHeader("Content-Disposition", "attachment;filename=" + fileName);
			resp.setContentType("application/octet-stream");
			OutputStream outputStream = resp.getOutputStream();  
			outputStream.write(b);
			outputStream.flush();  
			outputStream.close();
		}
	}

	/**
	 * mac转序列号 mac to license Key
	 * @param mac Mac地址
	 * @return LicenseKey Mac地址对应的序列号
	 */
	private static String calSerialKey(String mac) {
		mac = mac.toLowerCase();
		StringTokenizer st = new StringTokenizer(mac, ":");
		String[] s = new String[6];
		int T = 0;
		StringBuilder sb = new StringBuilder();
		while(st.hasMoreTokens()) {
			s[T] = st.nextToken();
			T++;
		}
		String hex = "";
		hex = Integer.toHexString((Integer.valueOf(s[0], 16) + (Integer.valueOf(s[2], 16) + 10)) % 256);
		sb.append(hex.length() == 1?"0" + hex:hex);
		hex = Integer.toHexString((Integer.valueOf(s[1], 16) + (Integer.valueOf(s[3], 16) + 13)) % 256);
		sb.append(hex.length() == 1?"0" + hex:hex);
		hex = Integer.toHexString((Integer.valueOf(s[2], 16) + (Integer.valueOf(s[4], 16) + 16)) % 256);
		sb.append(hex.length() == 1?"0" + hex:hex);
		hex = Integer.toHexString((Integer.valueOf(s[3], 16) + (Integer.valueOf(s[5], 16) + 19)) % 256);
		sb.append(hex.length() == 1?"0" + hex:hex);
		hex = Integer.toHexString((Integer.valueOf(s[4], 16) + (Integer.valueOf(s[0], 16) + 16)) % 256);
		sb.append(hex.length() == 1?"0" + hex:hex);
		hex = Integer.toHexString((Integer.valueOf(s[5], 16) + (Integer.valueOf(s[1], 16) + 19)) % 256);
		sb.append(hex.length() == 1?"0" + hex:hex);
		hex = Integer.toHexString((Integer.valueOf(s[0], 16) + (Integer.valueOf(s[2], 16) + 22)) % 256);
		sb.append(hex.length() == 1?"0" + hex:hex);
		hex = Integer.toHexString((Integer.valueOf(s[1], 16) + (Integer.valueOf(s[3], 16) + 26)) % 256);
		sb.append(hex.length() == 1?"0" + hex:hex);
		return sb.toString().toUpperCase();
	}

	/**
	 * 将速度格式化成kbps
	 * @param speed 源速度 1Mbps
	 * @return kbps 1024
	 */
	private static long[] parseSpeed(String speed) {
		long resp[] = null;
		try{
			String num = getNum(speed);
			//System.out.println(num);
			long maxLong = (Long.MAX_VALUE) / 1024 / 1024;
			int len = (maxLong + "").length() - 1;
			if (num == null || num.equals("") || num.length() >= len) {
				resp = null;
			} else {
				long bandWidth = Long.parseLong(num);
				long realBandWidth = 0;
				char lastStr = (speed.trim()).charAt(speed.length() - 1);
				if (lastStr == 'M' || lastStr == 'm') {
					realBandWidth = bandWidth * 1024;
				} else if (lastStr == 'G' || lastStr == 'g') {
					realBandWidth = bandWidth * 1024 * 1024;
				} else if(num.equals(speed)) {
					realBandWidth = bandWidth;
				} else {
					return null;
				}
				if(realBandWidth > 4294967040l) {
					return null;
				}
				resp = parseBasicAddNum(realBandWidth);
			}
		}catch (Exception e) {
			e.printStackTrace();
		}
		return resp;
	}

	/**
	 * 计算需要修改带宽值的大小
	 * @param bandSum 传入总带宽值 kbps
	 * @return 返回每一位需要累加的数字
	 */
	private static long[] parseBasicAddNum(long bandSum) {
		long[] addBasicNum = {16777216, 65536, 256, 1};
		// 对应着16进制 36c7 43e3
		long[] hexBasic = {54, 199, 67, 227};
		long[] addBasic = new long[4];

		long num = bandSum / addBasicNum[0];
		bandSum = bandSum - addBasicNum[0] * num;
		addBasic[3] += num;

		num = bandSum / addBasicNum[1];
		bandSum = bandSum - addBasicNum[1] * num;
		addBasic[2] += num;

		num = bandSum / addBasicNum[2];
		bandSum = bandSum - addBasicNum[2] * num;
		addBasic[1] += num;
		addBasic[0] += bandSum;

		for(int i= 0; i < 2; i++) {
			if (addBasic[i] + hexBasic[i] > 256) {
				addBasic[i] = addBasic[i] - 256;
				addBasic[i+1] ++;
			}
		}
		return addBasic;
	}
	
	/**
	 * 找出speed里面的数字
	 * @param speed 源速度,例如15M
	 * @return 找到数字,   15
	 */
	private static String getNum(String speed) {
		// 找出speed里面的数字
		String regEx = "\\d*";
		Pattern pat = Pattern.compile(regEx);
		Matcher mat = pat.matcher(speed);
		if(mat.find()){
			return mat.group();
		}
		return  null;
	}

	/**
	 * 格式化时间
	 * @param 源时间
	 * @return 格式化后的时间
	 */
	private static String parseDate(String srcDate) {
		String finalDate = "";
		SimpleDateFormat df = new SimpleDateFormat("yyyy-MM-dd");
		df.setLenient(false);
		SimpleDateFormat df2 = new SimpleDateFormat("yyyyMMdd");
		df2.setLenient(false);
		Date d = null;
		try {
			df.parse(srcDate);
			finalDate = srcDate;
		} catch (ParseException e) {
			try {
				d = df2.parse(srcDate);
				finalDate = df.format(d);
			} catch (ParseException e1) {
				finalDate = null;
			}
		}
		return finalDate;
	}
}
