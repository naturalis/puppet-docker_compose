puppet-docker_compose
=====================
Puppet role definition for deployment of docker-compose based setups

Parameters
-------------
Sensible defaults for Naturalis in init.pp.

```
- enablessl                   Enable apache SSL modules, see SSL example
- docroot                     Documentroot, match location with 'docroot' part of the instances parameter
- mysql_root_password         Root password for mysql server
- cron                        Enable hourly cronjob for drupal installation. 
```


Classes
-------------
- docker_compose


Dependencies
-------------

Docker-compose
--------------

It is started using Foreman which creates:

 - .env file
 - docker-compose.yml



Result
------

Limitations
-----------
This has been tested.

