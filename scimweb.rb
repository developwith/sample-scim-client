require 'rubygems'
require 'sinatra'
require 'oauth2'
require 'json'
require 'cgi'
require 'dalli'
require 'rack/session/dalli' # For Rack sessions in Dalli

$:.unshift File.expand_path('../', __FILE__)
require 'lib/oauthactions.rb'
require 'lib/scimutil.rb'

$stdout.sync = true

puts $config

# Dalli is a Ruby client for memcache
def dalli_client
  Dalli::Client.new(nil, :compression => true, :namespace => 'rack.session', :expires_in => 3600)
end

# Use the Dalli Rack session implementation
use Rack::Session::Dalli, :cache => dalli_client



get '/' do
  # Field list isn't very volatile - stash it in the session
  
  puts @access_token.get("#{$config['scim_server']}").parsed
  @users = @access_token.get("#{$config['scim_server']}/Users").parsed
  puts @users
  
  erb :index
end

get '/detail' do
  @user = @access_token.get("#{$config['scim_server']}/Users/#{params[:id]}").parsed
  erb :detail
end

post '/action' do
  if params[:new]
    @action_name = 'create'
    @action_value = 'Create'
    
    @user = Hash.new
    @user['id'] = ''
    @user['userName'] = ''
    
    done = :edit
  elsif params[:edit]
    @user = @access_token.get("#{$config['scim_server']}/Users/#{params[:id]}").parsed
    @action_name = 'update'
    @action_value = 'Update'

    done = :edit
  elsif params[:delete]
    @access_token.delete("#{$config['scim_server']}/Users/#{params[:id]}")
    @action_value = 'Deleted'
    
    @result = Hash.new
    @result['id'] = params[:id]

    done = :done
  end  
  
  erb done
end

post '/account' do
  if params[:create]
    body = {"userName"   => params[:userName]}.to_json

    @result = @access_token.post("#{$config['scim_server']}/Users/", 
      {:body => body, 
       :headers => {'Content-type' => 'application/json'}}).parsed
    @action_value = 'Created'
  elsif params[:update]
    body = {"userName"   => params[:userName]}.to_json

    # No response for an update
    @access_token.put("#{$config['scim_server']}/Users/#{params[:id]}", 
      {:body => body, 
       :headers => {'Content-type' => 'application/json'}})
    @action_value = 'Updated'
    
    @result = Hash.new
    @result['id'] = params[:id]
  end  
  
  erb :done
end


