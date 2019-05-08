# == Class: docker_compose
#
# Full description of class docker_compose here.
#
# === Authors
#
# Author Name <hugo.vanduijn@naturalis.nl>
#
#

class docker_compose (
  $version                      = '1.23.2',
  $repo_dir                     = '/opt/composeproject',
  $repo_source                  = 'https://github.com/naturalis/docker_mattermost.git',
  $repo_ensure                  = 'latest',
  $repo_revision                = 'master',
  $manageenv                    = 'no',
  $settings_hash                = { 'mysqlpassword' => 'MYSQLPASSWD',
                                    'basepath'      => '/data'
                                  },
  $docker_network_array         = ['web'],
  
# traefik options
  $traefik_toml                 = true,
  $traefik_toml_location        = "${role_drupal::repo_dir}/traefik.toml",
  $traefik_enable_ssl           = true,
  $traefik_debug                = false,
  $traefik_whitelist            = false,
  $traefik_whitelist_array      = ['172.16.0.0/16'],
  $traefik_domain               = 'naturalis.nl',
# cert hash = location to cert
  $traefik_cert_hash            = { '/etc/letsencrypt/live/site1.site.org/fullchain.pem' =>  '/etc/letsencrypt/live/site1.site.org/privkey.pem',
                                    '/etc/letsencrypt/live/site2.site.org/fullchain.pem' =>  '/etc/letsencrypt/live/site2.site.org/privkey.pem',
                                  },
# log rotation hash
  $logrotate_hash               = { 'apache2'    => { 'log_path' => '/data/www/log/apache2',
                                                      'post_rotate' => "(cd ${repo_dir}; docker-compose exec drupal service apache2 reload)",
                                                      'extraline' => 'su root docker'},
                                    'mysql'      => { 'log_path' => '/data/database/mysqllog',
                                                      'post_rotate' => "(cd ${repo_dir}; docker-compose exec db mysqladmin flush-logs)",
                                                      'extraline' => 'su root docker'}
                                 },

# cron hash
  $cron_hash                    = { 'dailypull'  => { 'command'   => "(cd ${repo_dir}; docker-compose pull; docker-compose up -d)",
                                                      'hour'      => '4',
                                                      'minute'    => '0'},
                                    'weeklyprune' => { 'command'   => "/usr/bin/docker system prune -a -f",
                                                      'hour'      => '6',
                                                      'minute'    => '0',
                                                      'weekday'   => '0'}
                                  },
# directory permissions
  $dir_hash                      = { '/data/config' => { 'owner' => 'root',
                                                         'group' => 'root',
                                                         'mode'  => '0777'},
                                     '/data/logs'   => { 'owner' => 'root',
                                                         'group' => 'root',
                                                         'mode'  => '0777'},
                                 },

# sensu check settings
  $checks_defaults    = {
    interval      => 600,
    occurrences   => 3,
    refresh       => 60,
    handlers      => ['default'],
    subscribers   => ['appserver'],
    standalone    => true },

){
# install packages
 ensure_packages(['git'], { ensure => 'present' })

# include stdlib
  include 'stdlib'

# install docker and docker-compose
  include 'docker'
  class {'docker::compose':
    ensure      => present,
    version     => $docker_compose::version,
    notify      => Exec['apt_update'],
  }

  Exec {
    path => ['/usr/local/bin/','/usr/bin','/bin'],
    cwd  => $docker_compose::repo_dir,
  }

# create docker_networks
  docker_network { $docker_compose::docker_network_array:
     ensure   => present,
  }

# create docker-compose repo_dir
#  file { $docker_compose::repo_dir:
#    ensure              => directory,
#    mode                => '0770',
#    require             => Class['docker'],
#  }

# checkout repo with docker-compose
  vcsrepo { $docker_compose::repo_dir:
    ensure    => $docker_compose::repo_ensure,
    source    => $docker_compose::repo_source,
    provider  => 'git',
    user      => 'root',
    revision  => $docker_compose::repo_revision,
    require   => Package['git'],
    notify    => [Exec['Pull containers'],Exec['Restart containers on change']],
  }

# create .env file 
  file { "${docker_compose::repo_dir}/.env":
    ensure   => file,
    mode     => '0600',
    replace  => $docker_compose::manageenv,
    content  => template('docker_compose/env.erb'),
    notify   => Exec['Restart containers on change'],
    require  => Vcsrepo[$docker_compose::repo_dir],
  }

# create traefik toml when enabled
  if ( $traefik_toml == true ) {
    file { $traefik_toml_location :
      ensure   => file,
      content  => template('docker_compose/traefik.toml.erb'),
      require  => Vcsrepo[$docker_compose::repo_dir],
      notify   => Exec['Restart traefik on change'],
    }
  }

  exec {'Restart traefik on change':
    refreshonly => true,
    command     => 'docker-compose restart traefik',
    require     => [
      Vcsrepo[$docker_compose::repo_dir],
      Docker_network[$docker_compose::docker_network_array],
      File["${docker_compose::repo_dir}/.env"]
    ]
  }

# pull containers when notified
  exec { 'Pull containers' :
    command      => 'docker-compose pull',
    refreshonly  => true,
  }

# restart containers when notified
  exec {'Restart containers on change':
    refreshonly => true,
    command     => 'docker-compose up -d',
    require     => [
      Exec['Pull containers'],
      File["${docker_compose::repo_dir}/.env"]
    ]
  }

# try to start docker-compose if no containers are running
  exec {'Start containers if none are running':
    command     => 'docker-compose up -d',
    onlyif      => 'docker-compose ps | tail -1 | grep -c "\-\-\-\-\-\-\-\-\-\-\-\-"',
    require     => [
      File["${docker_compose::repo_dir}/.env"]
    ]
  }

# create external container facts script
  file { '/usr/local/sbin/create_container_facts.sh':
    source       => 'puppet:///modules/docker_compose/create_container_facts.sh',
    mode         => '0700',
  }

# create 6 times a day schedule, should be often enough for refreshing external container facts
  schedule { '6 times a day':
    period => daily,
    repeat  => '6',
  }

# execute create_container_facts based on schedule
  exec { '/usr/local/sbin/create_container_facts.sh':
    schedule => '6 times a day',
  }

# create logrotation rules based on hash
create_resources('docker_compose::logrotate', $logrotate_hash)

# create cron jobs based on hash
create_resources('docker_compose::cron', $cron_hash)

# create directories based on hash
create_resources('docker_compose::dirs', $dir_hash)


}
