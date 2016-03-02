/**
 * @File AcServlet.java
 * @Package net.ruter.servlet
 */

package net.ruter.servlet;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.json.JSONObject;

/**
 * @author Ruter
 * @createTime 2016年2月27日
 * @tips 仅供学习与交流使用
 * @use 认证信息输出
 */
@WebServlet(urlPatterns={"/ac.do"}, loadOnStartup=1)
public class AcServlet extends HttpServlet {
	private static final long serialVersionUID = 1L;

	public AcServlet() {
		super();
	}
	protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		doPost(request, response);
	}

	/**
	 * 当软件请求服务器的ac.do时,输出code=200
	 * code 200 : 会让软件认为授权是正常的,且无需更新
	 * code 202 : 会让软件认为授权需要更新,随后软件会调用./bin/updateLic.sh来更新授权(该文件已删除)
	 */
	protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		Map<String, Object> map = new HashMap<String, Object>(); // 简单的输出,不需要解释吧
		map.put("code", 200);
		Random random = new Random();
		map.put("rdm", random.nextInt(500000));
		map.put("message", "ok");
		response.getWriter().print(new JSONObject(map).toString());
	}

}
