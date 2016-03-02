/**
 * @File KernelSearch.java
 * @Package net.ruter.servlet
 */


package net.ruter.servlet;

import java.io.IOException;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import net.ruter.tools.ServerSpeederKernelList;

/**
 * @author Ruter
 * @createTime 2016年2月27日
 * @tips 仅供学习与交流使用
 * @use 内核查找
 */

@WebServlet("/regenspeeder/kernelsearch")
public class KernelSearch extends HttpServlet {
	private static final long serialVersionUID = 1L;

	public KernelSearch() {
		super();
	}
	/**
	 * 内核请求servlet,请求地址会带kernel=XXX,服务端会寻找是否有合适的kernel,并输出一段shell
	 * 安装shell会运行这一段命令
	 * 
	 */
	protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		// 获得来自URL的kernel信息
		String kernel = request.getParameter("kernel");
		// 获得来自URL的服务器位数 32/64
		String kernelver = request.getParameter("ver");
		
		// 默认输出的话
		String kernelShell = "echo \"\"\n" // 输出一个回车
				+ "echo \"I'm sorry than you would see it, but there has no kernel inside\"\n" // 输出 I'm sorry that .....
				+ "echo \"\"\n" // 输出一个回车
				+ "if [ -d $ROOT_PATH ]; then\n" // 如果$ROOT_PATH存在
				+ "rm -r $ROOT_PATH\n"   // 删除
				+ "fi\n" // end if
				+ "exit 1"; // 结束shell
		if(kernel == null) { // 如果没有传kernel信息,直接输出默认的话
			response.getWriter().println(kernelShell);
			return;
		}
		String fullName = null;
		// String path = getServletContext().getRealPath("/");
		try{
			// File f = new File(new Config().getConfig("kernelPath")); // 从配置文件获得kernel的目录
			// File f = new File("/Users/Ruter/Desktop/kernel");
			// if(f.isDirectory()) { // 以防万一,如果是文件夹的话
				// File[] fs = f.listFiles(); // 获得文件夹下所有文件
				String[] kernelList = ServerSpeederKernelList.list;
				for(int i = 0 ; i < kernelList.length ; i++) { // 遍历这些文件
					String name = kernelList[i]; // 获得文件名字
					if(name.indexOf(kernel) >= 0) { // 如果文件名字包含内核名字
						if(kernelver == null || kernelver.equals("32")) { // 如果位数是32位的
							if(name.indexOf("x64") >= 0) { // 如果该内核是64位内核 ,因为我内核是_x64来区分64位,x32就没写x32
								continue; // 继续搜索
							}
							fullName = name; // 如果没有x64,找到对应的
							break;
						}else if(kernelver.equals("64")) { // 如果是64位系统
							if(name.indexOf("x64") >= 0) { // 且文件名也同时包含x64
								fullName = name; // 找到对应的
								break;
							}
						}
					}
				}
			//}
			String downfile = "$HOST/serverspeeder/kernel/" + fullName; // 下载地址为$HOST/serverspeeder/kernel/acce-xxxxxx
			if(fullName != null) {
				kernelShell = "cd $ROOT_PATH/bin\n"  // 进入锐速安装的/bin目录
						+ "echo \"downloading kernel "+ fullName +" ...\nit may takes some times\"\n" // 输出这段话,正在下载该内核中
						+ "wget -c -q -O "+ fullName +" \""+ downfile +"\"\n" // linux下载命令 wget -c -q -O 文件名 http://xxx.com/xx.exe
						+ "KERNELNAME=\""+ fullName +"\"";  // 给父级shell赋值,实际一键安装shell会下载这个网页生成的代码作为嵌入的shell运行
			}

			response.getWriter().print(kernelShell);
		}catch(Exception e){
			e.printStackTrace();
		}
	}

	protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		doGet(request, response);
	}

}
