# Install Python 3 and required system packages using platform package names.
if platform_family?('fedora', 'rhel')
  package %w[python3 python3-pip git postgresql-server postgresql-contrib libpq-devel]

  execute 'initialize_postgresql' do
    command 'postgresql-setup --initdb'
    creates '/var/lib/pgsql/data/PG_VERSION'
  end
else
  package %w[python3 python3-pip python3-venv git postgresql postgresql-contrib libpq-dev]
end

# Create application directory
directory node['fastapi_tutorial']['app_path'] do
  owner 'root'
  group 'root'
  mode '0755'
  recursive true
end

# Clone FastAPI tutorial repository
git node['fastapi_tutorial']['app_path'] do
  repository node['fastapi_tutorial']['repository']
  revision node['fastapi_tutorial']['revision']
  action :sync
end

# Create Python virtual environment
execute 'create_venv' do
  command "python3 -m venv #{node['fastapi_tutorial']['app_path']}/venv"
  creates "#{node['fastapi_tutorial']['app_path']}/venv"
end

# Install Python dependencies
execute 'install_dependencies' do
  command "#{node['fastapi_tutorial']['app_path']}/venv/bin/pip install -r #{node['fastapi_tutorial']['app_path']}/requirements.txt"
  cwd node['fastapi_tutorial']['app_path']
  action :run
end

# Configure PostgreSQL service
service 'postgresql' do
  action [:enable, :start]
end

# Create database and user
execute 'create_db_user' do
  command <<-EOH
    sudo -u postgres psql -c "CREATE USER fastapi WITH PASSWORD 'fastapi_password';" || true
    sudo -u postgres psql -c "CREATE DATABASE fastapi_db OWNER fastapi;" || true
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE fastapi_db TO fastapi;" || true
  EOH
  action :run
end

# Create environment configuration file
file "#{node['fastapi_tutorial']['app_path']}/.env" do
  content <<-ENV
PROJECT_NAME="FastAPI Tutorial"
API_VERSION=1.0.0
DATABASE_URL=postgresql://fastapi:fastapi_password@localhost/fastapi_db
  ENV
  mode '0644'
  owner 'root'
  group 'root'
end

# Create systemd service file
app_path = node['fastapi_tutorial']['app_path']
service_port = node['fastapi_tutorial']['service_port']
service_name = 'fastapi-tutorial'

file "/etc/systemd/system/#{service_name}.service" do
  content <<-SERVICE
[Unit]
Description=FastAPI Tutorial Service
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=#{app_path}
Environment="PATH=#{app_path}/venv/bin"
ExecStart=#{app_path}/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port #{service_port}
Restart=always

[Install]
WantedBy=multi-user.target
  SERVICE
  mode '0644'
  owner 'root'
  group 'root'
  notifies :run, 'execute[systemd_reload]', :immediately
end

# Reload systemd
execute 'systemd_reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Enable and start the service
service service_name do
  action [:enable, :start]
end
