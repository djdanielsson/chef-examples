#!/bin/bash

set -e

echo "🚀 Starting Chef provisioning in Vagrant VM..."

# Accept the EULA silently and persist acceptance for the provisioning user.
export CHEF_LICENSE=accept-silent

sudo dnf install -y \
    git \
    wget \
    gcc \
    gcc-c++ \
    make \
    cmake \
    ruby \
    ruby-devel \
    rubygem-ruby-shadow \
    libffi-devel \
    libyaml-devel

# Pin to Chef 18: Chef 19 gems from RubyGems require a license key.
sudo gem install chef-bin -v 18.8.54 --no-document
sudo gem install berkshelf --no-document

# Create the Chef cache directory with permissions suitable for a root Chef run.
sudo mkdir -p /var/chef-solo

# Change to cookbook directory
cd /chef-repo

# Download cookbook dependencies using Berkshelf
echo "📚 Downloading cookbook dependencies..."

/usr/local/bin/berks install
/usr/local/bin/berks vendor cookbooks

# Run Chef as root so it can manage system resources and write its cache.
echo "👨‍🍳 Running Chef in local mode..."
sudo env CHEF_LICENSE="$CHEF_LICENSE" /usr/local/bin/chef-client --local-mode -c solo.rb -j solo.json

echo "✅ Chef provisioning complete!"
echo ""
echo "🔗 Your sites are available at:"
echo "   • http://192.168.121.10 or https://192.168.121.10"
echo "   • https://test.cluster.local:8443"
echo "   • https://ci.cluster.local:8443"
echo "   • https://status.cluster.local:8443"
echo ""
echo "🖥️  From host machine:"
echo "   • http://localhost:8080"
echo "   • https://localhost:8443"
echo ""
echo "⚠️  Note: You may see SSL warnings since we're using self-signed certificates"
