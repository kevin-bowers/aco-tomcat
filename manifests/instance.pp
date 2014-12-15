# == Define: tomcat::userdb_entry
#
# Creates tomcat individual instances
#
# === Parameters:
#
# see README file for a description of all parameters
#
# === Actions:
#
# * Create tomcat instance
#
# === Requires:
#
# * tomcat class
#
# === Sample Usage:
#
#  ::tomcat::instance { 'myapp':
#    root_path    => '/home/tomcat/apps',
#    control_port => 9005
#  }
#
define tomcat::instance (
  $root_path            = '/opt/tomcat_instances',
  $service_name         = undef,
  $service_ensure       = 'running',
  $service_enable       = true,
  $service_start        = undef,
  $service_stop         = undef,
  $extras               = false,
  #----------------------------------------------------------------------------------
  # security and administration
  #----------------------------------------------------------------------------------
  $admin_webapps        = true,
  $create_default_admin = true,
  $admin_user           = 'tomcatadmin',
  $admin_password       = 'password',
  #----------------------------------------------------------------------------------
  # logging
  #----------------------------------------------------------------------------------
  $log4j_enable         = false,
  $log4j_conf_type      = 'ini',
  $log4j_conf_source    = "puppet:///modules/${module_name}/log4j/log4j.properties",
  #----------------------------------------------------------------------------------
  # server configuration
  #----------------------------------------------------------------------------------
  # listeners
  $apr_listener         = false,
  $apr_sslengine        = 'on',
  # jmx
  $jmx_listener         = false,
  $jmx_registry_port    = 8052,
  $jmx_server_port      = 8053,
  $jmx_bind_address     = '',
  #----------------------------------------------------------------------------------
  # server
  $control_port         = 8006,
  #----------------------------------------------------------------------------------
  # executor
  $threadpool_executor  = false,
  #----------------------------------------------------------------------------------
  # http connector
  $http_connector       = true,
  $http_port            = 8081,
  $use_threadpool       = false,
  #----------------------------------------------------------------------------------
  # ssl connector
  $ssl_connector        = false,
  $ssl_port             = 8444,
  #----------------------------------------------------------------------------------
  # ajp connector
  $ajp_connector        = true,
  $ajp_port             = 8010,
  #----------------------------------------------------------------------------------
  # engine
  $jvmroute             = undef,
  #----------------------------------------------------------------------------------
  # host
  $hostname             = 'localhost',
  $autodeploy           = true,
  $deployOnStartup      = true,
  $undeployoldversions  = false,
  $unpackwars           = true,
  #----------------------------------------------------------------------------------
  # valves
  $singlesignon_valve   = false,
  $accesslog_valve      = true,
  #----------------------------------------------------------------------------------
  # global configuration file
  #----------------------------------------------------------------------------------
  $catalina_home        = undef,
  $catalina_base        = undef,
  $jasper_home          = undef,
  $catalina_tmpdir      = undef,
  $catalina_pid         = undef,
  $java_home            = undef,
  $java_opts            = '-server',
  $catalina_opts        = undef,
  $security_manager     = false,
  $lang                 = undef,
  $shutdown_wait        = 30,
  $shutdown_verbose     = false,
  $custom_fragment      = undef) {
  # The base class must be included first
  if !defined(Class['tomcat']) {
    fail('You must include the tomcat base class before using any tomcat defined resources')
  }

  # enable 'instance' context
  $instance = true

  # -----------------------#
  # autogenerated defaults #
  # -----------------------#

  if $service_name == undef {
    $service_name_real = "${::tomcat::service_name_real}_${name}"
  } else {
    $service_name_real = $service_name
  }

  if $catalina_home == undef {
    $catalina_home_real = $::tomcat::catalina_home_real
  } else {
    $catalina_home_real = $catalina_home
  }

  if $catalina_base == undef {
    $catalina_base_real = "${root_path}/${name}"
  } else {
    $catalina_base_real = $catalina_base
  }

  if $jasper_home == undef {
    $jasper_home_real = $catalina_home_real
  } else {
    $jasper_home_real = $jasper_home
  }

  if $catalina_tmpdir == undef {
    $catalina_tmpdir_real = $::osfamily ? {
      'Debian' => '$JVM_TMP',
      default  => "${catalina_base_real}/temp"
    } } else {
    $catalina_tmpdir_real = $catalina_tmpdir
  }

  if $catalina_pid == undef {
    $catalina_pid_real = "/var/run/${service_name_real}.pid"
  } else {
    $catalina_pid_real = $catalina_pid
  }

  if $::osfamily == 'Debian' {
    $security_manager_real = $security_manager ? {
      true    => 'yes',
      default => 'no'
    } } else {
    $security_manager_real = $security_manager
  }

  # should we force download extras libs?
  if $log4j_enable or $jmx_listener {
    $extras_real = true
  } else {
    $extras_real = $extras
  }

  # --------#
  # service #
  # --------#

  if $::osfamily == 'Debian' and $tomcat::maj_version > 6 {
    file { "${service_name_real} service unit":
      path    => "/etc/init.d/${service_name_real}",
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => template("${module_name}/instance/${::tomcat::service_name_real}_init_deb.erb");
    }
  } elsif $::operatingsystem == 'Fedora' or ($::osfamily == 'RedHat' and $::operatingsystem != 'Fedora' and $::operatingsystemmajrelease >= 7) {
    file { "${service_name_real} service unit":
      path    => "/usr/lib/systemd/system/${service_name_real}.service",
      owner   => 'root',
      group   => 'root',
      content => template("${module_name}/instance/systemd_unit.erb")
    }
  } else {
    file { "${service_name_real} service unit":
      ensure  => link,
      path    => "/etc/init.d/${service_name_real}",
      owner   => 'root',
      group   => 'root',
      target  => $::tomcat::service_name_real,
      seltype => 'etc_t'
    }
  }

  service { $service_name_real:
    ensure  => $service_ensure,
    enable  => $service_enable,
    require => File["${service_name_real} service unit"];
  }

  # ---------------------#
  # instance directories #
  # ---------------------#

  File {
    owner => $::tomcat::tomcat_user_real,
    group => $::tomcat::tomcat_group_real
  }

  if !defined(File['tomcat instances root']) {
    file { 'tomcat instances root':
      ensure => directory,
      path   => $root_path
    }
  }

  file {
    "instance ${name} catalina_base":
      ensure  => directory,
      path    => $catalina_base_real,
      require => File['tomcat instances root'];

    "instance ${name} logs directory":
      ensure => directory,
      path   => "/var/log/${service_name_real}"
  } ->
  file {
    "instance ${name} bin directory":
      ensure => directory,
      path   => "${catalina_base_real}/bin";

    "instance ${name} conf directory":
      ensure => directory,
      path   => "${catalina_base_real}/conf";

    "instance ${name} lib directory":
      ensure => directory,
      path   => "${catalina_base_real}/lib";

    "instance ${name} logs symlink":
      ensure => link,
      path   => "${catalina_base_real}/logs",
      target => "/var/log/${service_name_real}";

    "instance ${name} webapps directory":
      ensure => directory,
      path   => "${catalina_base_real}/webapps";

    "instance ${name} work directory":
      ensure => directory,
      path   => "${catalina_base_real}/work";

    "instance ${name} temp directory":
      ensure => directory,
      path   => "${catalina_base_real}/temp"
  }

  if $::osfamily == 'Debian' {
    file { "instance ${name} conf/policy.d directory":
      ensure  => directory,
      path    => "${catalina_base_real}/conf/policy.d",
      require => File["${catalina_base_real}/conf"]
    } ->
    file { "instance ${name} catalina.policy":
      ensure => present,
      path   => "${catalina_base_real}/conf/policy.d/catalina.policy"
    }
  }

  # --------------------#
  # configuration files #
  # --------------------#

  # generate OS-specific variables
  $config_path = $::osfamily ? {
    'RedHat' => "/etc/sysconfig/${service_name_real}",
    default  => "/etc/default/${service_name_real}"
  }

  # generate and manage server configuration
  # Template uses:
  #-
  file { "instance ${name} server configuration":
    path    => "${catalina_base_real}/conf/server.xml",
    content => template("${module_name}/common/server.xml.erb"),
    notify  => Service[$service_name_real]
  }

  # generate and manage global parameters
  # Template uses:
  #-
  # note: defining the exact same parameters in several files may seem awkward,
  # but it avoids the randomness observed in some older releases due to buggy startup scripts
  file {
    "instance ${name} environment variables":
      path    => $config_path,
      content => template("${module_name}/common/setenv.erb"),
      notify  => Service[$service_name_real];

    "instance ${name} setenv.sh":
      ensure => link,
      path   => "${catalina_base_real}/bin/setenv.sh",
      target => $config_path
  }

  if $::osfamily == 'RedHat' {
    file { "instance ${name} default variables":
      path    => "${catalina_base_real}/conf/${service_name_real}.conf",
      content => "# See ${$config_path}"
    }
  }

  # ------#
  # users #
  # ------#

  # generate and manage UserDatabase file
  concat { "instance ${name} UserDatabase":
    path   => "${catalina_base_real}/conf/tomcat-users.xml",
    owner  => $::tomcat::tomcat_user_real,
    group  => $::tomcat::tomcat_group_real,
    mode   => '0640',
    notify => Service[$service_name_real]
  }

  concat::fragment { "instance ${name} UserDatabase header":
    target  => "instance ${name} UserDatabase",
    content => template("${module_name}/common/UserDatabase_header.erb"),
    order   => 01
  }

  concat::fragment { "instance ${name} UserDatabase footer":
    target  => "instance ${name} UserDatabase",
    content => template("${module_name}/common/UserDatabase_footer.erb"),
    order   => 03
  }

  # configure authorized access
  unless !$::tomcat::create_default_admin {
    ::tomcat::userdb_entry { "instance ${name} ${::tomcat::admin_user}":
      database => "instance ${name} UserDatabase",
      username => $admin_user,
      password => $admin_password,
      roles    => ['manager-gui', 'manager-script', 'admin-gui', 'admin-script']
    }
  }

  # --------------#
  # admin webapps #
  # --------------#

  if $admin_webapps { # generate OS-specific variables
    $admin_webapps_path = $::osfamily ? {
      'RedHat' => "\${catalina.home}/webapps",
      default  => "/usr/share/${::tomcat::admin_webapps_package_name_real}"
    }

    file { "instance ${name} Catalina dir":
      ensure  => directory,
      path    => "${catalina_base_real}/conf/Catalina",
      require => File["${catalina_base_real}/conf"]
    } ->
    file { "instance ${name} Catalina/${hostname} dir":
      ensure => directory,
      path   => "${catalina_base_real}/conf/Catalina/${hostname}"
    } ->
    file {
      "instance ${name} manager.xml":
        path    => "${catalina_base_real}/conf/Catalina/${hostname}/manager.xml",
        content => template("${module_name}/instance/manager.xml.erb");

      "instance ${name} host-manager.xml":
        path    => "${catalina_base_real}/conf/Catalina/${hostname}/host-manager.xml",
        content => template("${module_name}/instance/host-manager.xml.erb")
    }
  }

  # --------#
  # logging #
  # --------#

  if $log4j_enable {
    # no need to duplicate libraries if enabled globally
    unless $::tomcat::log4j_enable {
      # generate OS-specific variables
      $log4j_path = $::osfamily ? {
        'RedHat' => '/usr/share/java/log4j.jar',
        default  => '/usr/share/java/log4j-1.2.jar'
      }

      file { "instance ${name} log4j library":
        ensure => link,
        path   => "${catalina_base_real}/lib/log4j.jar",
        target => $log4j_path,
        notify => Service[$service_name_real]
      }
    }

    if $log4j_conf_type == 'xml' {
      file {
        "instance ${name} log4j xml configuration":
          ensure => present,
          path   => "${catalina_base_real}/lib/log4j.xml",
          source => $log4j_conf_source,
          notify => Service[$service_name_real];

        "instance ${name} log4j ini configuration":
          ensure => absent,
          path   => "${catalina_base_real}/lib/log4j.properties";

        "instance ${name} log4j dtd file":
          ensure => present,
          path   => "${catalina_base_real}/lib/log4j.dtd",
          source => "puppet:///modules/${module_name}/log4j/log4j.dtd"
      }
    } else {
      file {
        "instance ${name} log4j ini configuration":
          ensure => present,
          path   => "${catalina_base_real}/lib/log4j.properties",
          source => $log4j_conf_source,
          notify => Service[$service_name_real];

        "instance ${name} log4j xml configuration":
          ensure => absent,
          path   => "${catalina_base_real}/lib/log4j.xml";

        "instance ${name} log4j dtd file":
          ensure => absent,
          path   => "${catalina_base_real}/lib/log4j.dtd"
      }
    }

    file { "instance ${name} logging configuration":
      ensure => absent,
      path   => "${catalina_base_real}/conf/logging.properties",
      backup => true
    }
  }

  # -------#
  # extras #
  # -------#

  if $extras_real and !$::tomcat::extras_real { # no need to duplicate libraries if enabled globally
    Archive {
      cleanup => false,
      require => File["instance ${name} extras directory"],
      notify  => Service[$service_name_real]
    }

    archive {
      "instance ${name} catalina-jmx-remote.jar":
        path   => "${catalina_base_real}/lib/extras/catalina-jmx-remote-${::tomcat::version}.jar",
        source => "http://archive.apache.org/dist/tomcat/tomcat-${::tomcat::maj_version}/v${::tomcat::version}/bin/extras/catalina-jmx-remote.jar"
      ;

      "instance ${name} catalina-ws.jar":
        path   => "${catalina_base_real}/lib/extras/catalina-ws-${::tomcat::version}.jar",
        source => "http://archive.apache.org/dist/tomcat/tomcat-${::tomcat::maj_version}/v${::tomcat::version}/bin/extras/catalina-ws.jar"
      ;

      "instance ${name} tomcat-juli-adapters.jar":
        path   => "${catalina_base_real}/lib/extras/tomcat-juli-adapters-${::tomcat::version}.jar",
        source => "http://archive.apache.org/dist/tomcat/tomcat-${::tomcat::maj_version}/v${::tomcat::version}/bin/extras/tomcat-juli-adapters.jar"
      ;

      "instance ${name} tomcat-juli-extras.jar":
        path   => "${catalina_base_real}/lib/extras/tomcat-juli-extras-${::tomcat::version}.jar",
        source => "http://archive.apache.org/dist/tomcat/tomcat-${::tomcat::maj_version}/v${::tomcat::version}/bin/extras/tomcat-juli.jar"
    }

    file {
      "instance ${name} extras directory":
        ensure => directory,
        path   => "${catalina_base_real}/lib/extras";

      "instance ${name} tomcat-juli.jar":
        ensure => link,
        path   => "${catalina_base_real}/bin/tomcat-juli.jar",
        target => "${catalina_base_real}/lib/tomcat-juli-extras.jar";

      "instance ${name} catalina-jmx-remote.jar":
        ensure => link,
        path   => "${catalina_base_real}/lib/catalina-jmx-remote.jar",
        target => "extras/catalina-jmx-remote-${::tomcat::version}.jar";

      "instance ${name} catalina-ws.jar":
        ensure => link,
        path   => "${catalina_base_real}/lib/catalina-ws.jar",
        target => "extras/catalina-ws-${::tomcat::version}.jar";

      "instance ${name} tomcat-juli-adapters.jar":
        ensure => link,
        path   => "${catalina_base_real}/lib/tomcat-juli-adapters.jar",
        target => "extras/tomcat-juli-adapters-${::tomcat::version}.jar";

      "instance ${name} tomcat-juli-extras.jar":
        ensure => link,
        path   => "${catalina_base_real}/lib/tomcat-juli-extras.jar",
        target => "extras/tomcat-juli-extras-${::tomcat::version}.jar"
    }
  }
}