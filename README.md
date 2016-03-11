# ServSpeeder-AutoInstaller,该源码建议懂java web的人去尝试
### 说白了就是对ServerSpeeder的lic及自定义带宽,自定义到期时间的学习与研究

感谢 http://www.hostloc.com/thread-305480-1-1.html 公开序列号的算法<br>
也感谢ss官方群突如其来的爆料一张lic核心代码<br>

闲着蛋疼做了一个自动安装脚本,仅限Ubuntu14.04和14.10,服务器上保存着几乎所有的该系统内核,如果需要其他内核,麻烦自行寻找<br>
上传了服务端源码,非常简单的几句代码(也是我写过最简单的代码)<br>

### 首次写linux shell 肯定写的不太好 请多指教

servspdInstaller.sh 为一键安装(无需修改mac地址)

增加了tomcat直接跑的war包,配置文件里面配置

# 注意事项:
    1.写入hosts,将dl.serverspeeder.com重定向到shell顶部填写的HOSTADDR(这里就靠自己部署了,反正就是返回一个code:200,让ss认为lic是正常的,部署好不要忘了在hosts里面修改dl.serverspeeder.com,我默认写[hostIP]了)
注意事项: 需要把项目放在Tomcat-webapps-ROOT来运行,因为软件请求的时候地址是http://***.com/ac.do,或者通过nginx代理也可以<br>

# 接口使用提示
    1.lic生成,100M带宽默认: http://ip.com[:port]/regenspeeder/lic?mac=00:00:00:00:00:00
    2.lic生成指定日期: http://ip.com[:port]/regenspeeder/lic?mac=00:00:00:00:00:00&expires=2035-12-31
    3.lic生成指定带宽: http://ip.com[:port]/regenspeeder/lic?mac=00:00:00:00:00:00&bandwidth=100M
    4.生成日期参数和带宽参数可同时使用(废话...),带宽不填默认100M

# 使用方法
    1.在服务器上安装tomcat ubuntu为apt-get install tomcat7
    2.将仓库里srcANDwar里的servspd.war放到tomcat里面webapps包中(默认tomcat7的webapps目录是/var/lib/tomcat7/webapps),最好重命名成ROOT,这样网址中不需要加项目名,tomcat端口最好为80,也可以使用nginx进行反向代理,
    3.测试使用:ROOT http://您的服务器ip[:服务器端口]/
    非ROOT: http://您的服务器IP[:服务器端口]/servspd/
    4.如果显示一个 Hello World 字样就可以了
    5.打开servspdInstaller.sh 修改HOST=http://ip.com[:port]为自己服务器ip和项目名 例如HOST=http://10.1.1.1:8080/servspd
    6.额外:如果tomcat是80端口,且项目已经重命名成ROOT,则打开servspdInstaller.sh 修改HOSTADDR=[hostIP]为自己服务器ip 例如HOSTADDR=10.1.1.1
    7.将servspdInstaller.sh传到服务器上,输入 bash servspdInstaller.sh 即可进行自动安装

# 附加内核更改方法(Ubuntu) 这里用 3.13.0-29-generic 举例,其他服务器自行摸索:
    1.首先,安装需要的内核: sudo apt-get install linux-image-extra-3.13.0-29-generic
    2.输入 sudo uname -r,记住当前的内核,假设是 3.13.0-74-generic
    3.输入 sudo apt-get purge linux-image-3.13.0-74-generic linux-image-extra-3.13.0-74-generic
    4.因为上面命令执行后会删除当前内核然后会安装新内核,假设安装了3.xx.xx内核,这时可能不知道,用以下方式查找,输入sudo apt-get purge linux-image-3 然后按2次tab后会出现以下内容linux-image-3.13.0-29-generic  linux-image-extra-3.13.0-29-generic linux-image-3.XX.X-XX-generic linux-image-extra-XX.X-XX-generic,如果出现了4个,则记住xx的数字,并继续输入完整,最后完整命令是:sudo apt-get purge linux-image-3.XX.X-XX-generic linux-image-extra-3.XX.X-XX-generic,如果只出现2个,则跳过
    5.sudo update-grub更新内核
    6.sudo reboot 重启服务器
    7.重启之后 再次使用uname -r则看到使用了3.13.0-29-generic内核,直接下载servspdInstaller.sh并配置好里面的地址,上传到到服务器,然后sudo bash servspdInstaller.sh进行安装
    8.具体参考 http://bbs.tcp.hk/thread-84-1-1.html

# 更改记录
    1.2016年02月29日23:02, 修正输入时间会导致错乱问题,原来版本当输入2100年时,会生成23xx的文件
    2.2016年03月01日16:40, 取消kernel内核单独提供,一并放入网页中,这样无需进行nginx部署
    3.2016年03月02日13:41, 不再更新
    4.2016年03月11日12:22, 反正有那么多了,就直接改名ServerSpeeder-AutoInstaller.
项目为java servlet项目,Eclipse Project<br>

### 需要自行部署eclipse项目,来重定向ss的定时lic检测,否则会因为无法更新lic而导致ss加速无效
## 此项目仅供交流和学习使用, 不得用于其他非法用途, 使用后请自觉删除
