package net.ruter.servlet;

import java.io.File;
import java.io.IOException;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import net.ruter.tools.Config;

@WebServlet("/regenspeeder/kernelsearch")
public class KernelSearch extends HttpServlet {
	private static final long serialVersionUID = 1L;

	public KernelSearch() {
		super();
	}
	/**
	 * kernel request with patameter kernel=XXX, server will find kernel in webContent/regenspeeder/hclient/kernel, and print {kernelShell}
	 * install.sh will run the shell after request ended
	 * -----
	 * 内核请求servlet,请求地址会带kernel=XXX,服务端会在webContent/regenspeeder/hclient/kernel寻找是否有合适的kernel,并输出一段shell
	 * 安装shell会运行这一段命令
	 * 
	 */
	protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		String kernel = request.getParameter("kernel");
		String kernelver = request.getParameter("ver");
		String kernelShell = "echo \"\"\n"
				+ "echo \"I'm sorry than you would see it, but there has no kernel inside\"\n"
				+ "echo \"\"\n"
				+ "if [ -d $ROOT_PATH ]; then\n"
				+ "rm -r $ROOT_PATH\n"
				+ "fi\n"
				+ "exit 1";
		if(kernel == null) {
			response.getWriter().println(kernelShell);
			return;
		}
		String fullName = null;
		//String path = getServletContext().getRealPath("/");
		try{
			File f = new File(new Config().getConfig("kernelPath"));
			//File f = new File("/Users/Ruter/Desktop/kernel");
			if(f.isDirectory()) {
				File[] fs = f.listFiles();
				for(int i = 0 ; i < fs.length ; i++) {
					String name = fs[i].getName();
					if(name.indexOf(kernel) >= 0) {
						if(kernelver == null || kernelver.equals("32")) {
							if(name.indexOf("x64") >= 0) {
								continue;
							}
							fullName = name;
							break;
						}else if(kernelver.equals("64")) {
							if(name.indexOf("x64") >= 0) {
								fullName = name;
								break;
							}
						}
					}
				}
			}
			String downfile = "$HOST/serverspeeder/kernel/" + fullName;
			if(fullName != null) {
				kernelShell = "cd $ROOT_PATH/bin\n"
						+ "echo \"downloading kernel "+ fullName +" ...\nit may takes some times\"\n"
						+ "wget -c -q -O "+ fullName +" \""+ downfile +"\"\n"
						+ "KERNELNAME=\""+ fullName +"\"";
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
