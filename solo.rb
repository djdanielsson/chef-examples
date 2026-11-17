file_cache_path "/var/chef-solo"
cookbook_path ["/chef-repo/cookbooks", "/chef-repo/cookbooks-*/cookbooks"]
data_bag_path "/chef-repo/data_bags"
encrypted_data_bag_secret "/chef-repo/test/fixtures/encrypted_data_bag_secret"
log_level :info
log_location STDOUT