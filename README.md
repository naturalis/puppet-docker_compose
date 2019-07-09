puppet-docker_compose
=====================
Puppet role definition for deployment of docker-compose based setups

Parameters
-------------
Sensible defaults for Naturalis in init.pp.

```
  $version                      = '1.23.2',  # docker-compose version
  $repo_dir                     = '/opt/composeproject',  # directory where docker_compose.yml should be, checked out from github repo
  $repo_source                  = 'https://github.com/naturalis/repo_with_docker_compose_yml.git'
  $repo_ensure                  = 'latest',
  $repo_revision                = 'master',
  $manageenv                    = 'no',  # .env will always be created from settings_hash manageenv = no will not overwrite any changes done to the file. 
  $settings_hash                = { 'mysqlpassword' => 'MYSQLPASSWD',  # .env is created from hash 
                                    'basepath'      => '/data'
                                  },
  $docker_network_array         = ['web'], # array with docker networks which will be created. 

# traefik options
  $traefik_toml                 = true,  # create traefik.toml based on template
  $traefik_toml_location        = '/opt/composeproject/traefik.toml', # location of traefik.toml file
  $traefik_enable_ssl           = true, # enable SSL in traefik
  $traefik_debug                = false, # enable debug mode
  $traefik_whitelist            = false, # enable whitelist
  $traefik_whitelist_array      = ['172.16.0.0/16'], # array with ip ranges for whitelist
  $traefik_domain               = 'naturalis.nl',

# enable certificate requests using traefik
  $traefik_transip_dns          = false,

# cert hash = location to cert, only used when traefik_transip_dns = false
  $traefik_cert_hash            = { '/etc/letsencrypt/live/site1.site.org/fullchain.pem' =>  '/etc/letsencrypt/live/site1.site.org/privkey.pem
                                    '/etc/letsencrypt/live/site2.site.org/fullchain.pem' =>  '/etc/letsencrypt/live/site2.site.org/privkey.pem
                                  },
# settings related to traefik letsencrypt cert based on DNS check, only used when traefik_transip_dns = true
  $letsencrypt_email            = 'aut@naturalis.nl',
  $transip_accountname          = 'naturalis',
  $transip_API_key              = '<private key here>',

# log rotation hash, logrotation rules which will be installed on the server because containers are usually stripped from logrotation. 
  $logrotate_hash               = { 'apache2'    => { 'log_path' => '/data/www/log/apache2',
                                                      'post_rotate' => "(cd /opt/composeproject; docker-compose exec drupal service apache2 reload)",
                                                      'extraline' => 'su root docker'},
                                    'mysql'      => { 'log_path' => '/data/database/mysqllog',
                                                      'post_rotate' => "(cd /opt/composeproject; docker-compose exec db mysqladmin flush-logs)",
                                                      'extraline' => 'su root docker'}
                                 },

# cron hash, hash with cronjobs see cron.pp for possible options 
  $cron_hash                    = { 'dailypull'  => { 'command'   => "(cd /opt/composeproject; docker-compose pull; docker-compose up -d)",
                                                      'hour'      => '4',
                                                      'minute'    => '0'}
                                    'weeklyprune' => { 'command'   => "/usr/bin/docker system prune -a -f",
                                                      'hour'      => '6',
                                                      'minute'    => '0',
                                                      'weekday'   => '0'}
                                  },
# directory permissions, hash with custom directory permissions
  $dir_hash                      = { '/data/config' => { 'owner' => 'root',
                                                         'group' => 'root',
                                                         'mode'  => '0777'},
                                     '/data/logs'   => { 'owner' => 'root',
                                                         'group' => 'root',
                                                         'mode'  => '0777'},
                                 },
```

Docker-compose repository
-------------
Requirements of the repository containing docker-compose.yml
example: https://github.com/naturalis/docker-percolator

- Create .gitignore with atleast .env as content
- Make sure all variables can be managed using the .env file
- When Traefik is used then create volume to the traefik.toml location and acme.json, example: `- /opt/composeproject/traefik.toml:/traefik.toml`
- Create labels in each container you want to access through traefik, don't make port mappings to 80,443 or 8080 avoid duplicate port declarations. Multiple certificaties, wildcard, multidomain or single site can be added to the traefik.toml config, traefik will find out which cert to use based on the traefik_frontend_rule label.
example: 
```
  labels:
      - "traefik.backend=ppdb-grafana"
      - "traefik.docker.network=web"
      - "traefik.enable=true"
      - "traefik.port=3000"
      - ${GRAFANA_URL_CONFIG:-traefik.frontend.rule=Host:reports.ppdb.naturalis.nl}
```

Guidelines/hints: 
- Make sure there are logging rules for every container, used in docker-compose version 3.4 is can be done by setting a default in top of the docker-compose file: 
```
x-logging:
  &default-logging
  options:
    max-size: '10m'
    max-file: '5'
  driver: json-file
```

and creating a single line in each service: 
```
    logging: *default-logging
```

- Use tags for containers, not latest to avoid unexpected upgrades.. example : `image: postgres:10.5`
- cronjob weekly prune is advised, this will clean up all docker related images, containers and networks which are not currently in use. disk usage in /var/lib/docker grows rather fast when this is not run atleast once a week. 
- Very important, create .gitignore so secrets won't appear public in github. minimal advised example:
```
.env
.transip.key
traefik.toml
acme.json
```

The Foreman
-------------
Hashes look a bit different when used with the Foreman, when class parameters are overriden they do not always convert to hash correctly and are set to type: string instead of hash, these examples might help customize the settings rather easiliy.

- cron_hash example
```
dailypull:
  command: "(cd /opt/ppdb; docker-compose pull; docker-compose up -d)"
  hour: '4'
  minute: '0'
weeklyprune:
  command: "/usr/bin/docker system prune -a -f"
  hour: '6'
  minute: '0'
  weekday: '0'
create_dataset_xenocanto:
  command: cd /opt/ppdb; docker-compose run validator php create_dataset.php --config=/config/xeno-canto.ini
    2>&1 >> /var/log/validator/validator.log
  minute: 23
  hour: 11
```

- dir_hash example
```
"/data":
  group: root
  mode: '0775'
  owner: root
"/var/log/validator":
  group: root
  mode: '0700'
  owner: root
```

- logrotate_hash example
```
validator:
  log_path: "/var/log/validator"
  extraline: su root root
```

- settings_hash example
```
MINIO_WAARNEMING_DATA_DIR: "/data/validator/minio-waarneming"
MINIO_XENOCANTO_DATA_DIR: "/data/validator/minio-xenocanto"
MINIO_NATURALIS_DATA_DIR: "/data/validator/minio-naturalis"
ELASTICSEARCH_DATA: "/data/elasticsearch-data"
ELASTICSEARCH_BACKUP: "/data/elasticsearch-backup"
GRAFANA_DATA: "/data/grafana-data"
```

- facter facts
script `/usr/local/sbin/create_container_facts.sh`  is created and runs 6 times a day using a schedule in init.pp. The script creates `/etc/facter/facts.d/metadata_containers.json` which contains a valid json output based on docker ps in json output.


Traefik and SSL certificates
-------------

Overview of options related to traefik
```
# traefik options
  $traefik_toml                 = true,  # create traefik.toml based on template
  $traefik_toml_location        = '/opt/composeproject/traefik.toml', # location of traefik.toml file
  $traefik_enable_ssl           = true, # enable SSL in traefik
  $traefik_debug                = false, # enable debug mode
  $traefik_whitelist            = false, # enable whitelist
  $traefik_whitelist_array      = ['172.16.0.0/16'], # array with ip ranges for whitelist
  $traefik_domain               = 'naturalis.nl',

# enable certificate requests using traefik
  $traefik_transip_dns          = false,

# cert hash = location to cert, only used when traefik_transip_dns = false
  $traefik_cert_hash            = { '/etc/letsencrypt/live/site1.site.org/fullchain.pem' =>  '/etc/letsencrypt/live/site1.site.org/privkey.pem
                                    '/etc/letsencrypt/live/site2.site.org/fullchain.pem' =>  '/etc/letsencrypt/live/site2.site.org/privkey.pem
                                  },
# settings related to traefik letsencrypt cert based on DNS check, only used when traefik_transip_dns = true
  $letsencrypt_email            = 'aut@naturalis.nl',
  $transip_accountname          = 'naturalis',
  $transip_API_key              = '<private key here>',
```

### Method 1: Use existing certificates on Host

- Requires external method for obtaining and placing certificates on the system running docker-compose, for example using letsencryptssl::installcert ( https://github.com/naturalis/puppet-letsencryptssl ). Documentation and instruction in Infra-docs
- Set options default as seen above, only modify $traefik_cert_hash with correct certificates. 
- Use docker-compose service part as shown below, make sure $CERTDIR and $TRAEFIK_TOML_FILE locations are correct.

```
  traefik:
    image: traefik:1.7.12
    container_name: traefik
    restart: unless-stopped
    logging: *default-logging
    ports:
      - 80:80
      - 443:443
      - 8081:8080
    networks:
      - default
      - web
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ${TRAEFIK_TOML_FILE:-./traefik.toml}:/traefik.toml
      - ${CERTDIR:-/etc/letsencrypt}:/etc/letsencrypt
```
#### troubleshooting
Not too much known issues but the first puppet run will always generate errors either due to either traefik and letsencryptssl tries to get everything running during install, the first one being installed will fail. The errors can be ignored.


### Method 2: Use TransIP DNS hook from within traefik for obtaining certificates

- Create Transip private API key
- Modified default options: 
  - $traefik_transip_dns = true
  - $transip_API_key              = '<private TransIP API key here>',
- The module will create a traefik.toml with transip DNS hook and create a .transip.key and a acme.json file
- Use docker-compose service part as shown below, make sure the TRANSIP environment variables are correct and the toml, acme.json and .transip.key volumes are correct.
- Don't forget to create a .gitignore so the .transip.key and acme.json won't appear public in github. 

```
  traefik:
    image: traefik:1.7.12
    restart: unless-stopped
    environment:
      - TRANSIP_PRIVATE_KEY_PATH=/.transip.key
      - TRANSIP_ACCOUNT_NAME=${TRANSIP_ACCOUNT_NAME:-naturalis}
    ports:
      - 80:80
      - 443:443
      - 8081:8080
    networks:
      - web
      - default
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ${TRAEFIK_TOML_FILE:-./traefik/traefik.toml}:/traefik.toml
      - ${ACME_JSON:-./acme.json}:/acme.json
      - ./.transip.key:/.transip.key
    logging: *default-logging
```

#### troubleshooting

- The volume mapping will create acme.json directory if there is no empty acme.json created before starting docker-compose, stop docker-compose, run puppet or create acme.json empty file with 0700 permissions and root ownership before starting docker-compose again.
- If transip environment or key are not correct then there will appear a traefik selfsigned cert in acme.json, new attempt to request a certificate from letsencrypt will not be done within 24 hours unless docker-compose is stopped and contents of acme.json is cleared.


- cert_hash example
```
"/etc/letsencrypt/live/s3.naturalis.ppdb.naturalis.nl/fullchain.pem": "/etc/letsencrypt/live/s3.naturalis.ppdb.naturalis.nl/privkey.pem"
"/etc/letsencrypt/live/s3.waarneming.ppdb.naturalis.nl/fullchain.pem": "/etc/letsencrypt/live/s3.waarneming.ppdb.naturalis.nl/privkey.pem"
"/etc/letsencrypt/live/s3.xenocanto.ppdb.naturalis.nl/fullchain.pem": "/etc/letsencrypt/live/s3.xenocanto.ppdb.naturalis.nl/privkey.pem"
"/etc/letsencrypt/live/ppdb.naturalis.nl/fullchain.pem": "/etc/letsencrypt/live/ppdb.naturalis.nl/privkey.pem"
```


Classes
-------------
- docker_compose
- docker_compose::dirs
- docker_compose::cron
- docker_compose::logrotate


Dependencies
-------------
- puppetlabs/docker
- puppetlabs/stdlib

Docker-compose
--------------

It is started using Foreman which creates:

 - .env file
 - repo checkout which should contain docker-compose.yml
 - logrotate rules
 - traefik configuration file with option for multiple ssl certificates
 - traefik configuration file with TransIP DNS hook for requesting ssl certificates
 - crontab jobs
 - custom directory permissions
 - docker and docker-compose binaries 
 - docker networks 
 - container facts in facter

Result
------
 - hopefully working application based on docker-compose 

Compatibility
-----------
This has been tested on Puppet5 with Ubuntu 18.04 

