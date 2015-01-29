#
# Cookbook Name:: pdns
# Recipe:: _source
#
# Copyright 2014, Aetrion, LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe 'build-essential'

package 'libtool'
package 'pkg-config'
package 'libboost-all-dev'
package 'ragel'

# Base install directory
pdns_basepath = node['pdns']['source']['path']
# Filename
pdns_filename = pdns_file(node['pdns']['source']['url'])
# Base install dir + Filename
pdns_filepath = "#{pdns_basepath}/#{pdns_filename}"
# Base install dir + (Filename - Extension)
pdns_dir = pdns_dir(pdns_filename)

remote_file pdns_filepath do
  source node['pdns']['source']['url']
  action :create_if_missing
end

user node['pdns']['user'] do
  system true
  shell  '/bin/false'
end

bash 'unarchive_source' do
  cwd node['pdns']['source']['path']
  code <<-EOH
  tar xjf #{::File.basename(pdns_filepath)} -C #{::File.dirname(pdns_filepath)}
  EOH
  not_if { ::File.directory?("#{pdns_dir}") }
end

directory node['pdns']['config_dir'] do
  owner node['pdns']['user']
  group node['pdns']['group']
  mode '0755'
end

execute 'pdns: bootstrap' do
  # This insanity is documented in the README
  command './bootstrap && ./bootstrap'
  cwd pdns_dir
  creates "#{pdns_dir}/configure"
end

pdns_source_module_requirements.each do |pkg|
  package pkg
end

execute 'pdns: configure' do
  command './configure ' +
    "--with-modules='#{node['pdns']['source']['backends'].join(' ')}' " +
    "--sysconfdir=#{node['pdns']['config_dir']} " +
    '--without-lua'
  cwd pdns_dir
  creates "#{pdns_dir}/config.h"
end

execute 'pdns: build' do
  command 'make'
  cwd pdns_dir
  creates "#{pdns_dir}/pdns/pdns_server"
end

execute 'pdns: install' do
  command 'make install'
  cwd pdns_dir
  creates '/usr/local/sbin/pdns_server'
end

template '/etc/init.d/pdns' do
  source 'pdns.init.erb'
  owner 'root'
  group 'root'
  mode 0755
end

# pdns::service  just registers pdns as a debian init service
include_recipe "pdns::_service"