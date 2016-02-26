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

@WebServlet("/regenspeeder/lic")
public class Lic extends HttpServlet {
	private static final long serialVersionUID = 1L;

	public Lic() {
		super();
	}
	/**
	 * apx-***.lic build hree
	 * install.sh will request this servlet with parameter mac=**
	 * this servlet will generate legal license file by mac address, and install.sh will download it
	 * ----
	 * apx**.lic 在这里生成
	 * install.sh会带2mac=***请求这个servlet, servlet会根据mac地址来生成一个新的license,并让instlal.sh进行下载
	 */
	protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		String mac = request.getParameter("mac");
		String expires = request.getParameter("expires");
		String bandWidth = request.getParameter("bandwidth");
		func(mac, expires, bandWidth, response);
	}

	protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		doGet(request, response);
	}
	public void func(String mac, String exp, String bandWidth, HttpServletResponse resp) throws IOException {
		Config config = new Config();
		String expires = null;
		if(exp == null || exp.length() == 0){
			expires = config.getConfig("serverspeederexpire");
		}else{
			expires = parseDate(exp);
		}
		boolean error = false;
		String msg = null;
		// this is apx-**.lic
		// 这就是apx.lic文件的流数据,直接输出这个流数据会看到序列号为00000和到期日期为0000-00-00的文件
		byte[] b = {-78, 38, -68, 39, 78, 34, 15, 83, -30, 45, -122, 58, 30, -55, 19, -34, -90, -106, 27, -48, 70, -48, 52, -24, -120, 24, -26, -115, 38, 13, 120, 19, -32, -76, 34, 93, 59, 17, -32, 11, 80, 97, 4, 86, 103, -63, 42, -12, -104, 41, -110, -85, -122, -18, 122, 79, -124, -63, -17, -125, 2, 10, 26, -36, -46, 63, 31, -6, 105, 62, 93, -44, -61, 24, -88, -118, -91, 63, 31, 24, -56, 28, -77, -76, 4, -22, -74, -97, 89, -103, 63, -65, 98, -67, 55, 58, 117, 63, -6, 67, -50, -93, -12, 39, 54, -57, 67, -29, -93, 102, 68, 81, 19, -20, -9, 66, 5, -28, 10, -13, 44, -77, 12, 83, 66, -52, 94, -67, -104, 31, 126, 2, -87, 50, 111, 56, 35, -24, 48, 78, 77, 32, -7, 66, -14, 11, -33, -66, -82, -17, -8, 67};
		long[] speedAdding = null;
		if (bandWidth == null || bandWidth.equals("")) {
			speedAdding = parseSpeed(config.getConfig("bandWidth"));
		} else {
			speedAdding = parseSpeed(bandWidth);
		}
		
		String fileName = null;
		if(mac == null || mac.indexOf(":") == -1 || config.split(mac, ":").length!= 6) {
			error = true;
			msg = "Mac address is not corrent";
		}else if(expires == null){
			error = true;
			msg = "parameter expires is not corrent,accepted format: YYYY-MM-DD or YYYYMMDD";
		} else if(speedAdding == null) {
			error = true;
			msg = "parameter bandwidth too large or not current, accepted format: 10M 20M 100M 1G";
		} else{
			String data = calSerialKey(mac);
			fileName = "apx-"+ expires +".lic";
			try {
				// 修改带宽
				for (int i = 0; i < 4; i++) {
					byte tmp = (byte) speedAdding[i];
					b[104 + i] = (byte) (b[104 + i] + tmp);
				}
				
				for(int i = 0 ; i < data.length() ; i++) {
					char c = (char) (data.charAt(i) - '0');
					int offset = c;
					// license key recrod is start with b[64]
					// 从64位开始为license信息,为什么我会知道,是因为我凑了一个下午凑出这个位置来的
					b[64 + i] = (byte) (b[64 + i] + (byte)offset);
				}
				StringTokenizer st = new StringTokenizer(expires, "-");
				int T = 0;
				int[] ymdSp = new int[3];
				while(st.hasMoreTokens()) {
					ymdSp[T] = Integer.parseInt(st.nextToken());
					T++;
				}
				int divide = ymdSp[0] / 256 + 1;
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
	 * @param mac
	 * @return LicenseKey
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
