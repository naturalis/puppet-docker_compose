# directory creation
define docker_compose::dirs (
  $mode       = '0600',
  $owner      = undef,
  $group      = undef,
){

# configure directory
  file { $title:
    ensure      => 'directory',
    mode        => $mode,
    owner       => $owner,
    group       => $group,
  }

}
