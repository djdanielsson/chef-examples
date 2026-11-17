package 'nginx' do
  action :install
end

template '/etc/nginx/nginx.conf' do
  source 'nginx.conf.erb'
  mode '0644'
  notifies :reload, 'service[nginx]', :delayed
end

template '/etc/nginx/conf.d/security.conf' do
  source 'security.conf.erb'
  mode '0644'
  notifies :reload, 'service[nginx]', :delayed
end

service 'nginx' do
  supports restart: true, reload: true, status: true
  action [:enable, :start]
end

directory '/etc/nginx/secrets' do
  owner 'root'
  group 'root'
  mode '0700'
end

site_secret = Chef::EncryptedDataBagItem.load('nginx_secrets', 'site')

file '/etc/nginx/secrets/site_token' do
  content site_secret['token']
  owner 'root'
  group 'root'
  mode '0600'
  sensitive true
end

data_bag('nginx_sites').each do |item_name|
  site = data_bag_item('nginx_sites', item_name)
  site_name = site['id']
  config = site

  directory config['document_root'] do
    owner 'nginx'
    group 'nginx'
    mode '0755'
    recursive true
    action :create
  end
  
  site_folder = site_name.split('.').first
  
  cookbook_file "#{config['document_root']}/index.html" do
    source "#{site_folder}/index.html"
    owner 'nginx'
    group 'nginx'
    mode '0644'
    action :create
  end
end
