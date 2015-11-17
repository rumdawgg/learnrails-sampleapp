# config valid only for current version of Capistrano
lock '3.4.0'

set :application, 'sampleapp'
set :repo_url, 'git@github.com:rumdawgg/learnrails-sampleapp.git'


set :scm, :git
# Run with cap production deploy branchname=ops
if "#{ENV['branchname']}".empty?
  set :branch, "master"
else
  set :branch, "#{ENV['branchname']}"
end
set :currentbranch, "current"

# Deploy Settings
set :deploy_user, 'www'
set :deploy_to, "/home/#{fetch(:deploy_user)}/apps"
set :keep_releases, 5
set :log_level, :debug
set :format, :pretty
set :pty, true
set :ssh_options, {
  user: "#{fetch(:deploy_user)}",
  forward_agent: true
}

# Run db:migrate only if migrations exist
set :conditionally_migrate, true

# Check custom directories exist
set :custom_directories, %W{local_shared/passenger_restart}


# Make sure rails and rake commands are called with bundle exec
SSHKit.config.command_map[:rake]  = "bundle exec rake"
SSHKit.config.command_map[:rails] = "bundle exec rails"

# Check files and directories on all servers
namespace :environment_check do
  desc "Check config files exist in shared/config"
  task :config_files do
    on roles(:app, :resque) do |host|
      fetch(:linked_files).each do |file|
        if test "([ -r #{fetch(:deploy_to)}/shared/#{file} ])"
          info "#{fetch(:deploy_to)}/shared/#{file} exists on #{host}"
        else
          error "#{fetch(:deploy_to)}/shared/#{file} do not exist on #{host}"
        end
      end
    end
  end

  desc "Check if custom directories exist"
  task :custom_directories do
    on roles(:app, :resque) do |host|
      fetch(:custom_directories).each do |dir|
        if test "([ -d #{fetch(:deploy_to)}/#{dir} ])"
          info "#{fetch(:deploy_to)}/#{dir} exists on #{host}"
        else
          execute :mkdir, '-p', "#{fetch(:deploy_to)}/#{dir}"
        end
      end
    end
  end

  desc "Run all environment check tasks"
  task :all do
    invoke 'environment_check:config_files'
    invoke 'environment_check:custom_directories'
  end
end

# Deploy tasks
namespace :deploy do
    desc "Restart application using a rolling restart"
    task :rolling_restart do
        on roles(:app), in: :sequence, wait: 10 do |host|
            on roles(:web) do
                set_haproxy_state('disable', "#{host}")
            end 
            sleep(10)
            execute :touch, "#{fetch(:deploy_to)}/local_shared/passenger_restart/restart.txt"
            sleep(10)
            on roles(:web) do
                set_haproxy_state('enable', "#{host}")
            end
        end
    end

    before :deploy, 'environment_check:all'
    after :publishing, :restart
end