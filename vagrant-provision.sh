#!/bin/bash

set -e

echo "🚀 Starting Chef provisioning in Vagrant VM..."

sudo dnf install -y \
    git \
    wget \
    gcc \
    gcc-c++ \
    make \
    cmake \
    ruby \
    ruby-devel \
    libffi-devel \
    libyaml-devel

sudo gem install chef-cli --no-document
sudo gem install berkshelf

ENV CHEF_LICENSE=accept-no-persist

# Create chef cache directory
mkdir -p /var/chef-solo

# Change to cookbook directory
cd /chef-repo

# Download cookbook dependencies using Berkshelf
echo "📚 Downloading cookbook dependencies..."

/usr/local/bin/berks install
/usr/local/bin/berks vendor cookbooks

# Accept Chef license and set up
export CHEF_LICENSE=accept-silent

# Accept Chef license and run Chef
echo "👨‍🍳 Running Chef Solo..."
/opt/chef/bin/chef-solo -c solo.rb -j solo.json

echo "✅ Chef provisioning complete!"
echo ""
echo "🔗 Your sites are available at:"
echo "   • http://192.168.56.10 or https://192.168.56.10"
echo "   • https://test.cluster.local:8443"
echo "   • https://ci.cluster.local:8443"
echo "   • https://status.cluster.local:8443"
echo ""
echo "🖥️  From host machine:"
echo "   • http://localhost:8080"
echo "   • https://localhost:8443"
echo ""
echo "⚠️  Note: You may see SSL warnings since we're using self-signed certificates"
