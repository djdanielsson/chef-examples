# Chef Policyfile for the recipes currently configured in solo.json.
name 'chef-examples'

default_source :supermarket

cookbook 'nginx-multisite', path: './cookbooks/nginx-multisite'
cookbook 'cache', path: './cookbooks/cache'
cookbook 'fastapi-tutorial', path: './cookbooks/fastapi-tutorial'

run_list 'nginx-multisite', 'cache', 'fastapi-tutorial'
