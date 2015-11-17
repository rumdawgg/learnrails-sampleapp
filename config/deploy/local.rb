set :rails_env, 'local'
set :stage, 'local'
	server 'rails.lan.chicarello.com', roles: %w{app db web}

namespace :deploy do
  task :restart do
    invoke 'deploy:rolling_restart'
  end
end