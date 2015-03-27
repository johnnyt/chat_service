# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.require_version '>= 1.6'
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'docker'

def vagrant_host(config)
  if RUBY_PLATFORM =~ /darwin/
    config.vagrant_machine = 'dockerhost'
    config.vagrant_vagrantfile = 'vagrant_host/Vagrantfile'
  end
end

Vagrant.configure('2') do |config|
  config.vm.define 'nsq_data' do |v|
    v.vm.provider 'docker' do |d|
      d.name = 'nsq_data'
      d.image = 'busybox:latest'
      d.volumes = ['/data']
      d.has_ssh = false
      d.remains_running = false

      vagrant_host d
    end
  end

  config.vm.define :nsqd do |v|
    v.vm.provider :docker do |d|
      d.name = 'nsqd'
      d.image = 'ploxiln/nsq:0.3.0'
      d.ports = ['4150:4150','4151:4151']
      d.has_ssh = false
      d.create_args = ['--volumes-from','nsq_data']

      vagrant_host d
    end
  end

  config.vm.define :nsqadmin do |v|
    v.vm.provider :docker do |d|
      d.image = 'ploxiln/nsq:0.3.0'
      d.cmd  = ['/bin/nsqadmin', '--nsqd-http-address=nsqd:4151']
      d.link 'nsqd:nsqd'
      d.ports = ['49171:4171']
      d.has_ssh = false
      d.create_args = ['--volumes-from','nsq_data']

      vagrant_host d
    end
  end

  config.vm.define :nginx do |v|
    v.vm.provider :docker do |d|
      #d.image = 'johnnyt/nginx-push-stream:latest'
      d.build_dir = 'docker/nginx_push_stream'
      d.link 'nsqd:nsqd'
      d.ports = ['49080:80']
      d.has_ssh = false
      d.volumes = ['/vagrant/etc/nginx:/etc/nginx']
      d.cmd =  ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;", "-c", "/vagrant/etc/nginx/nginx.conf"]

      vagrant_host d
    end
  end
end
