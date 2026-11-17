default['nginx']['ssl']['certificate_path'] = '/etc/ssl/certs'
default['nginx']['ssl']['private_key_path'] = '/etc/ssl/private'

default['security']['fail2ban']['enabled'] = true
default['security']['ufw']['enabled'] = true
default['security']['ssh']['disable_root'] = true
default['security']['ssh']['password_auth'] = false