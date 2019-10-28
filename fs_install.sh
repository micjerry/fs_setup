#/bin/bash

FS_VERSION="freeswitch-1.8.5"
INSTALL_DEST="/opt/freeswitch"
INSTALL_LOG_DEST="/var/log/freeswitch"
FS_CONFIG_PATH="${INSTALL_DEST}/etc/freeswitch"

RECORDING_PATH="/opt/fs_record"

AKS_WDD="978243"

TMP_INSTALL_ROOT="/opt/tmp_fs1.8"
FS_INSTALL_PATH="${TMP_INSTALL_ROOT}/${FS_VERSION}"
THP_INSTALL_PATH="${TMP_INSTALL_ROOT}/tmpthd"

CUR_PATH=`pwd`
THP_CFG_PATH=${CUR_PATH}/config
THP_SND_PATH=${CUR_PATH}/sounds

THP_PACKAGE_DIR=${CUR_PATH}/pkgs
THP_FS_PKG="${FS_VERSION}.tar.gz"
THP_SQLITE_PKG="sqlite-autoconf-3270100.tar.gz"
THP_CURL_PKG="curl-7.66.0.tar.gz"
THP_SPEEX_PKG="speexdsp-SpeexDSP-1.2rc3.tar.gz"
THP_SPHINX_PKG="pocketsphinx-0.8.tar.gz"
THP_SPBASE_PKG="sphinxbase-0.8.tar.gz"
THP_MYSQLODBC_PKG="mysql-connector-odbc-8.0.15-linux-ubuntu18.04-x86-64bit.tar.gz"

EXT_IP=
LOCAL_IP=
MYSQL_DATAPATH="/opt/mysqldb"

export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig/

die() {
    echo "$1"
    exit 1
}

usage() {
  script_name=`basename "$0"`
  echo "./${script_name} -e [ext_ip] -l [local_ip]"
  exit 0
}

env_prepare()
{
    [ -z "${EXT_IP}" ] && die "ext ip not set"
    [ -z "${LOCAL_IP}" ] && die "local ip not set"
    [ -d ${TMP_INSTALL_ROOT} ] && rm -rf ${TMP_INSTALL_ROOT}
    mkdir -p ${TMP_INSTALL_ROOT}
    mkdir -p ${THP_INSTALL_PATH}
    mkdir -p ${MYSQL_DATAPATH}
    
    [ -d ${RECORDING_PATH} ] || mkdir -p ${RECORDING_PATH}
    
    [ -f ${THP_PACKAGE_DIR}/${THP_FS_PKG} ] || die "${THP_FS_PKG} not exist"
    tar -xzvf ${THP_PACKAGE_DIR}/${THP_FS_PKG} -C ${TMP_INSTALL_ROOT}
    [ -f ${THP_PACKAGE_DIR}/${THP_SPHINX_PKG} ] && cp ${THP_PACKAGE_DIR}/${THP_SPHINX_PKG} ${FS_INSTALL_PATH}/libs
    [ -f ${THP_PACKAGE_DIR}/${THP_SPBASE_PKG} ] && cp ${THP_PACKAGE_DIR}/${THP_SPBASE_PKG} ${FS_INSTALL_PATH}/libs
    cp ${THP_SND_PATH}/*.tar.gz ${FS_INSTALL_PATH}
}

install_deps_os() {
    apt-get update
    apt-get -y install git-core subversion build-essential autoconf automake libtool libncurses5 libncurses5-dev make libjpeg-dev
    apt-get -y install libspeex-dev
    apt-get -y install libedit-dev
    apt-get -y install libtiff-dev
    apt-get -y install libopus0 opus-tools
    apt-get -y install bison
    apt-get -y install gawk
    apt-get -y install libsndfile-dev
    apt-get -y install lua5.3 lua5.3-dev
    apt-get -y install unixodbc-dev
    apt-get -y install libmyodbc
    apt-get -y install mysql-server
    apt-get -y install nginx
    apt-get -y install dos2unix
    apt-get -y install libpcre3 libpcre3-dev
    apt-get -y install libssl-dev
    update-alternatives --set awk /usr/bin/gawk
    
    cp /usr/include/lua5.3/*.h ${FS_INSTALL_PATH}/src/mod/languages/mod_lua/
    ln -sf /usr/lib/x86_64-linux-gnu/liblua5.3.so /usr/lib/x86_64-linux-gnu/liblua.so
    
    #install mysql odbc lib
    tar -xzvf ${THP_PACKAGE_DIR}/${THP_MYSQLODBC_PKG} -C ${THP_INSTALL_PATH} > /dev/null 2>&1
    local mysqllib_path=`echo ${THP_MYSQLODBC_PKG} | sed -e "s/.tar.gz//g"`
    [ -d ${THP_INSTALL_PATH}/${mysqllib_path} ] || die "unzip mysql odbc lib failed" 
    cp ${THP_INSTALL_PATH}/${mysqllib_path}/lib/libmyodbc8a.so /usr/lib/x86_64-linux-gnu/odbc/
}

install_curl()
{
    apt-get -y remove libcurl3
    local curl_path=`echo ${THP_CURL_PKG} | sed -e "s/.tar.gz//g"`
    [ -f "${THP_PACKAGE_DIR}/${THP_CURL_PKG}" ] || die "${THP_CURL_PKG} not exist"
    tar -xzvf ${THP_PACKAGE_DIR}/${THP_CURL_PKG} -C ${THP_INSTALL_PATH} > /dev/null 2>&1
    [ -d ${THP_INSTALL_PATH}/${curl_path} ] || die "unpack ${THP_CURL_PKG} failed"
    cd ${THP_INSTALL_PATH}/${curl_path} > /dev/null 2>&1
    ./configure
    make
    make install
    cd - > /dev/null 2>&1
}

install_speex()
{
    apt-get -y remove libspeex-dev
    local speex_path=`echo ${THP_SPEEX_PKG} | sed -e "s/.tar.gz//g"`
    [ -f "${THP_PACKAGE_DIR}/${THP_SPEEX_PKG}" ] || die "${THP_SPEEX_PKG} not exist"
    tar -xzvf ${THP_PACKAGE_DIR}/${THP_SPEEX_PKG} -C ${THP_INSTALL_PATH} > /dev/null 2>&1
    [ -d ${THP_INSTALL_PATH}/${speex_path} ] || die "unpack ${THP_SPEEX_PKG} failed"
    cd ${THP_INSTALL_PATH}/${speex_path} > /dev/null 2>&1
    ./autogen.sh
    ./configure
    make
    make install
    
    rm -f /usr/local/lib/pkgconfig/speex.pc
    [ -f /usr/local/lib/pkgconfig/speexdsp.pc ] && cp /usr/local/lib/pkgconfig/speexdsp.pc /usr/local/lib/pkgconfig/speex.pc
    cd - > /dev/null 2>&1    
}

install_db() {
    [ -f ${THP_CFG_PATH}/odbc.ini ] || die "odbc.ini not exist"
    [ -f ${THP_CFG_PATH}/odbcinst.ini ] || die "odbc.ini not exist"
    cp -f ${THP_CFG_PATH}/odbc.ini /etc
    cp -f ${THP_CFG_PATH}/odbcinst.ini /etc
    dos2unix /etc/odbc.ini
    dos2unix /etc/odbcinst.ini
    mysql_pass=`cat ${THP_CFG_PATH}/odbc.ini | grep "PASSWORD" | awk -F = '{print $2}' | sed 's/ //g'`
    [ -z "${mysql_pass}" ] && die "mysql password was not configed"
    
    sed -i "s#datadir\(.*\)#datadir         =${MYSQL_DATAPATH}#" /etc/mysql/mysql.conf.d/mysqld.cnf
    
    systemctl start mysql.service
    /usr/bin/mysqladmin -u root password ${mysql_pass}
    echo "CREATE DATABASE freeswitch;" | mysql -uroot -p${mysql_pass} 
    echo "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${mysql_pass}'" | mysql -uroot -p${mysql_pass}
    echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_pass}';" | mysql -uroot -p${mysql_pass}
}

install_deps_sqlite() {
    apt-get -y remove sqlite3:
    local sqlite_path=`echo ${THP_SQLITE_PKG} | sed -e "s/.tar.gz//g"`
    [ -f "${THP_PACKAGE_DIR}/${THP_SQLITE_PKG}" ] || die "${THP_SQLITE_PKG} not exist"
    tar -xzvf ${THP_PACKAGE_DIR}/${THP_SQLITE_PKG} -C ${THP_INSTALL_PATH} > /dev/null 2>&1
    [ -d ${THP_INSTALL_PATH}/${sqlite_path} ] || die "unpack ${THP_SQLITE_PKG} failed"
    cd ${THP_INSTALL_PATH}/${sqlite_path} > /dev/null 2>&1
    ./configure --prefix=/usr/local
    make
    make install
    cd - > /dev/null 2>&1
}

install_fs() {
    cd ${FS_INSTALL_PATH}
    ./bootstrap.sh
    
    #enable modules
    sed -i 's_#\(asr\_tts/mod\_pocketsphinx\)_\1_' modules.conf
    sed -i 's_#\(asr\_tts/mod\_unimrcp\)_\1_' modules.conf
    sed -i 's_#\(asr\_tts/mod\_tts\_commandline\)_\1_' modules.conf
    sed -i 's_#\(xml\_int/mod\_xml\_curl\)_\1_' modules.conf
    
    #disable modules
    sed -i 's_applications/mod\_enum_#&_' modules.conf
    sed -i 's_applications/mod\_signalwire_#&_' modules.conf
    sed -i 's_xml\_int/mod\_xml\_cdr_#&_' modules.conf
    
    ./configure "--prefix=${INSTALL_DEST}" "--with-logfiledir=${INSTALL_LOG_DEST}" "--enable-core-odbc-support" "-C"
    [ "$?" != 0 ] && die "configure failed"
    make
    [ "$?" != 0 ] && die "make failed"
    make install
    [ "$?" != 0 ] && die "make install failed"
    make uhd-sounds-install
    [ "$?" != 0 ] && die "make uhd-sounds-install failed"
    make uhd-moh-install
    [ "$?" != 0 ] && die "make uhd-moh-install failed"
    make samples
    [ "$?" != 0 ] && die "make samples failed"
    
    cp -f ${THP_CFG_PATH}/freeswitch /etc/init.d/
    chmod 755 /etc/init.d/freeswitch
    update-rc.d -f freeswitch defaults
    cp debian/freeswitch-sysvinit.freeswitch.default /etc/default/freeswitch
    adduser --disabled-password  --quiet --system --home ${INSTALL_DEST} --gecos "FreeSwitch Voice Platform" --ingroup daemon freeswitch
    adduser freeswitch audio
  
    chown -R freeswitch:daemon ${INSTALL_DEST}
    chmod -R o-rwx ${INSTALL_DEST}
    
    ln -sf ${INSTALL_DEST}/bin/fs_cli /usr/local/bin/
    cd - > /dev/null 2>&1
    systemctl daemon-reload
}

config_fs() {
    #config event_socket bind to local
    sed -i 's/::/127.0.0.1/g' ${FS_CONFIG_PATH}/autoload_configs/event_socket.conf.xml
    
    #mod default config
    sed -i "/default_password/s/=[0-9]\+/=${AKS_WDD}/" ${FS_CONFIG_PATH}/vars.xml
    
    sed -i 's#internal_sip_port=\(.*\)"#internal_sip_port=6650"#' ${FS_CONFIG_PATH}/vars.xml
    sed -i 's#internal_tls_port=\(.*\)"#internal_tls_port=6651"#' ${FS_CONFIG_PATH}/vars.xml
    sed -i 's#internal_ssl_enable=\(.*\)"#internal_ssl_enable=true"#' ${FS_CONFIG_PATH}/vars.xml
    
    sed -i 's#external_sip_port=\(.*\)"#external_sip_port=6680"#' ${FS_CONFIG_PATH}/vars.xml
    sed -i 's#external_tls_port=\(.*\)"#external_tls_port=6681"#' ${FS_CONFIG_PATH}/vars.xml
    sed -i 's#external_ssl_enable=\(.*\)"#external_ssl_enable=true"#' ${FS_CONFIG_PATH}/vars.xml
    
    sed -i "/bind_server_ip=auto/a \ \ <X-PRE-PROCESS cmd=\"set\" data=\"local_ip=${LOCAL_IP}\"/>" ${FS_CONFIG_PATH}/vars.xml
    sed -i "/bind_server_ip=auto/a \ \ <X-PRE-PROCESS cmd=\"set\" data=\"ext_ip=${EXT_IP}\"/>" ${FS_CONFIG_PATH}/vars.xml
    
    sed -i "/outbound_codec_prefs/a \ \ <X-PRE-PROCESS cmd=\"set\" data=\"recordings_dir=${RECORDING_PATH}\"/>" ${FS_CONFIG_PATH}/vars.xml
    
    #config codecs
    sed -i 's#global_codec_prefs=\(.*\)"#global_codec_prefs=OPUS,H264,PCMU,PCMA,VP8"#' ${FS_CONFIG_PATH}/vars.xml
    sed -i 's#outbound_codec_prefs=\(.*\)"#outbound_codec_prefs=OPUS,H264,PCMU,PCMA,VP8"#' ${FS_CONFIG_PATH}/vars.xml
  
    sed -i 's#console_loglevel=\(.*\)"#console_loglevel=err"#' ${FS_CONFIG_PATH}/vars.xml
    sed -i 's#sip_tls_ciphers=\(.*\)"#sip_tls_ciphers=ALL:!ADH:!LOW:!EXP:!MD5:!RC4:@STRENGTH"#' ${FS_CONFIG_PATH}/vars.xml
    
    #set load modules
    sed -i 's#<!-- *\(<load module="mod_h26x"/>\) *-->#\1#' ${FS_CONFIG_PATH}/autoload_configs/modules.conf.xml
    sed -i 's#<!-- *\(<load module="mod_rtmp"/>\) *-->#\1#' ${FS_CONFIG_PATH}/autoload_configs/modules.conf.xml
    sed -i 's#<!-- *\(<load module="mod_xml_curl"/>\) *-->#\1#' ${FS_CONFIG_PATH}/autoload_configs/modules.conf.xml
    sed -i 's#<!-- *\(<load module="mod_pocketsphinx"/>\) *-->#\1#' ${FS_CONFIG_PATH}/autoload_configs/modules.conf.xml
    sed -i 's#<!-- *\(<load module="mod_tts_commandline"/>\) *-->#\1#' ${FS_CONFIG_PATH}/autoload_configs/modules.conf.xml
    sed -i '/mod_tts_commandline/a \ \ \ \ <load module="mod_unimrcp"/>' ${FS_CONFIG_PATH}/autoload_configs/modules.conf.xml
    
    #set unload modules
    sed -i 's#\(<load module="mod_enum"/>\)#<!--\1-->#'  ${FS_CONFIG_PATH}/autoload_configs/modules.conf.xml
    sed -i 's#\(<load module="mod_signalwire"/>\)#<!--\1-->#'  ${FS_CONFIG_PATH}/autoload_configs/modules.conf.xml
    sed -i 's#\(<load module="mod_rtmp"/>\)#<!--\1-->#'  ${FS_CONFIG_PATH}/autoload_configs/modules.conf.xml
    
    #set switch config
    sed -i '/max-sessions/s/value="\(.*\)"/value="5000"/' ${FS_CONFIG_PATH}/autoload_configs/switch.conf.xml
    sed -i '/sessions-per-second/s/value="\(.*\)"/value="100"/' ${FS_CONFIG_PATH}/autoload_configs/switch.conf.xml  
    sed -i '/dsn:username:password/a \ \ \ \ <param name="core-db-dsn" value="odbc://freeswitch::"/>' ${FS_CONFIG_PATH}/autoload_configs/switch.conf.xml
    sed -i 's#<!-- *\(<param name="auto-create-schemas" value="true"/>\) *-->#\1#' ${FS_CONFIG_PATH}/autoload_configs/switch.conf.xml
    sed -i 's#<!-- *\(<param name="auto-clear-sql" value="true"/>\) *-->#\1#' ${FS_CONFIG_PATH}/autoload_configs/switch.conf.xml
    sed -i '/core-dbtype/a \ \ \ \ <param name="core-dbtype" value="MYSQL"/>' ${FS_CONFIG_PATH}/autoload_configs/switch.conf.xml
    
    #sip profile
    sed -i 's#<!-- *\(<param name="rtcp-audio-interval-msec" value="5000"/>\) *-->#\1#' ${FS_CONFIG_PATH}/sip_profiles/internal.xml
    sed -i 's#<!-- *\(<param name="rtcp-video-interval-msec" value="5000"/>\) *-->#\1#' ${FS_CONFIG_PATH}/sip_profiles/internal.xml
    
    sed -i 's#<!-- *\(<param name="aggressive-nat-detection" value="true"/>\) *-->#\1#' ${FS_CONFIG_PATH}/sip_profiles/internal.xml
    sed -i 's#<!-- *\(<param name="inbound-bypass-media" value="true"/>\) *-->#\1#' ${FS_CONFIG_PATH}/sip_profiles/internal.xml
    sed -i 's#<!-- *\(<param name="disable-transcoding" value="true"/>\) *-->#\1#' ${FS_CONFIG_PATH}/sip_profiles/internal.xml
    sed -i '/apply-inbound-acl/a \ \ \ \ <param name="tcp-pingpong" value="20000"/>' ${FS_CONFIG_PATH}/sip_profiles/internal.xml
    sed -i '/rtp-timeout-sec/s/300/30/' ${FS_CONFIG_PATH}/sip_profiles/internal.xml
    
    #use odbc
    sed -i '/dsn:user:pass/a \ \ \ \ <param name="odbc-dsn" value="odbc://freeswitch::"/>' ${FS_CONFIG_PATH}/sip_profiles/internal.xml
    
    sed -i '/rtp-ip/s/$${local_ip_v4}/$${local_ip}/' ${FS_CONFIG_PATH}/sip_profiles/internal.xml
    sed -i '/sip-ip/s/$${local_ip_v4}/$${local_ip}/' ${FS_CONFIG_PATH}/sip_profiles/internal.xml
    sed -i '/ext-rtp-ip/s/auto-nat/$${ext_ip}/' ${FS_CONFIG_PATH}/sip_profiles/internal.xml
    sed -i '/ext-sip-ip/s/auto-nat/$${ext_ip}/' ${FS_CONFIG_PATH}/sip_profiles/internal.xml

    sed -i '/auth-calls/a \ \ \ \ <param name="inbound-bypass-media" value="true"/>' ${FS_CONFIG_PATH}/sip_profiles/external.xml
    sed -i '/rtp-ip/s/$${local_ip_v4}/$${local_ip}/' ${FS_CONFIG_PATH}/sip_profiles/external.xml
    sed -i '/sip-ip/s/$${local_ip_v4}/$${local_ip}/' ${FS_CONFIG_PATH}/sip_profiles/external.xml
    sed -i '/ext-rtp-ip/s/auto-nat/$${ext_ip}/' ${FS_CONFIG_PATH}/sip_profiles/external.xml
    sed -i '/ext-sip-ip/s/auto-nat/$${ext_ip}/' ${FS_CONFIG_PATH}/sip_profiles/external.xml
    
    #use odbc
    sed -i '/enable-3pcc/a \ \ \ \ <param name="odbc-dsn" value="odbc://freeswitch::"/>' ${FS_CONFIG_PATH}/sip_profiles/external.xml
    
    #remove ipv6
    rm -f ${FS_CONFIG_PATH}/sip_profiles/*ipv6.xml
    rm -rf ${FS_CONFIG_PATH}/sip_profiles/*ipv6
    
    #add asr diaplan
    cp ${THP_CFG_PATH}/asr.xml ${FS_CONFIG_PATH}/dialplan/
    sed -i '/context/s/default/asr/' ${FS_CONFIG_PATH}/sip_profiles/internal.xml
    
}

config_verto() {
    sed -i '/outbound-codec-string/s/value="\(.*\)"/value="opus,vp8,h264"/' ${FS_CONFIG_PATH}/autoload_configs/verto.conf.xml
    sed -i '/inbound-codec-string/s/value="\(.*\)"/value="opus,vp8,h264"/' ${FS_CONFIG_PATH}/autoload_configs/verto.conf.xml  
    sed -i '/ext-rtp-ip/a \ \ \ \ \ \ <param name="ext-rtp-ip" value="$${ext_ip}"/>' ${FS_CONFIG_PATH}/autoload_configs/verto.conf.xml
    
    sed -i '/jsonrpc-allowed-methods/a \ \ \ \ \ \ <param name="jsonrpc-allowed-event-channels" value="demo,conference,presence"/>' \
     ${FS_CONFIG_PATH}/directory/default.xml
     
    sed -i '/Allow live array sync for Verto/a \ \ \ \ \ \ <param name="conference-flags" value="livearray-sync|livearray-json-status"/>' ${FS_CONFIG_PATH}/autoload_configs/conference.conf.xml
    
    #install tokens
    mkdir -p ${FS_CONFIG_PATH}/tls/
    rm -f ${FS_CONFIG_PATH}/tls/wss.pem
    cp ${THP_CFG_PATH}/wss.pem ${FS_CONFIG_PATH}/tls/
    chown -R freeswitch:daemon ${FS_CONFIG_PATH}/tls
    
    cp ${THP_CFG_PATH}/wss.pem /etc/nginx
    cp ${THP_CFG_PATH}/server.key /etc/nginx
    
    mv -f /etc/nginx/nginx.conf /etc/nginx/nginxcf.bak
    cp ${THP_CFG_PATH}/nginx.conf /etc/nginx
    dos2unix /etc/nginx/nginx.conf
    sed -i "s/PUBLICIP/${EXT_IP}/" /etc/nginx/nginx.conf
    
    rm -rf /var/verto
    cp -r ${FS_INSTALL_PATH}/html5/verto /var
    sed -i "/verto_demo_passwd/s/1234/${AKS_WDD}/" /var/verto/demo/verto.js
    sed -i "/verto_demo_passwd/s/1234/${AKS_WDD}/" /var/verto/video_demo/verto.js
    
}

while [[ $# -gt 0 ]]
do
  key="$1"
  case $key in
    -e|--ext)
      EXT_IP="$2"
      shift
      ;; 
    -l|--local)
      LOCAL_IP="$2"
      shift
      ;;        
    -h|--help)
      usage
      ;;
    *)
      echo "invalid arguments"
      usage
      ;;
  esac
  shift 
done

env_prepare
install_deps_os
install_curl
install_speex
install_deps_sqlite
install_db
install_fs
config_fs
config_verto
