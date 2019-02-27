# Logrotate creation
define docker_compose::logrotate (
  $log_path,
  $post_rotate      = undef,
  $pre_rotate       = undef,
  $extraline        = undef,
  $rotate           = 14,
){

# configure logrotate 
  file { "/etc/logrotate.d/${title}":
    mode        => '0600',
    content     => template('docker_compose/logrotate.erb'),
  }

}
