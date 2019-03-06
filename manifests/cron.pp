# cron creation
define docker_compose::cron (
  $ensure           = 'present',
  $minute           = '*',
  $hour             = '*',
  $weekday          = '*',
  $month            = '*',
  $monthday         = '*',
  $user             = 'root',
  $environment      = 'PATH=/bin:/usr/bin:/usr/sbin:/usr/local/bin',
  $command,
){

# configure logrotate 
  cron { $title:
    ensure      => $ensure,
    minute      => $minute,
    hour        => $hour,
    weekday     => $weekday,
    month       => $month,
    monthday    => $monthday,
    environment => $environment,
    command     => $command,
    user        => $user,
  }

}
