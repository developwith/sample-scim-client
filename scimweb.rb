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

# Dalli is a Ruby client for memcache
def dalli_client
  Dalli::Client.new(nil, :compression => true, :namespace => 'rack.session', :expires_in => 3600)
end

# Use the Dalli Rack session implementation
use Rack::Session::Dalli, :cache => dalli_client


get '/' do
  ## @access_token.get("#{$config['scim_path']}").parsed
  resultList = @access_token.get("#{$config['scim_path']}Users/").parsed
  @users = resultList['Resources']
  erb :index
end

get '/detail' do
  @user = @access_token.get("#{$config['scim_path']}Users/#{params[:id]}").parsed
  puts @user
  erb :detail
end

post '/action' do
  if params[:new]
    @action_name = 'create'
    @action_value = 'Create'
    
    @user = Hash.new
    @user['id'] = ''
    @user['userName'] = ''
    @user['emails'] = []
    @user['emails'][0] = Hash.new
    @user['emails'][0]['value'] = ''
    @user['name'] = Hash.new
    @user['name']['givenName'] = ''
    @user['name']['familyName'] = ''
    
    done = :edit
  elsif params[:edit]
    @user = @access_token.get("#{$config['scim_path']}Users/#{params[:id]}").parsed
    @action_name = 'update'
    @action_value = 'Update'

    done = :edit
  elsif params[:delete]
    @access_token.delete("#{$config['scim_path']}Users/#{params[:id]}")
    @action_value = 'Deleted'
    
    @result = Hash.new
    @result['id'] = params[:id]

    done = :done
  end  
  
  erb done
end

post '/user' do
   body = {"userName"   => params[:userName],
           "name" => {"givenName"=>params[:firstName],"familyName"=>params[:lastName] },
           "emails" => [ {"value"=> params[:email]}]
      }.to_json
 
  if params[:create]
    @result = @access_token.post("#{$config['scim_path']}Users/", 
      {:body => body, 
       :headers => {'Content-type' => 'application/json'}}).parsed
    @action_value = 'Created'
  elsif params[:update]
    # No response for an update
    @access_token.put("#{$config['scim_path']}Users/#{params[:id]}", 
      {:body => body, 
       :headers => {'Content-type' => 'application/json'}})
    @action_value = 'Updated'
    
    @result = Hash.new
    @result['id'] = params[:id]
  end  
  
  erb :done
end


