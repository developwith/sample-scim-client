
require 'sinatra'
require 'oauth2'
require 'json'
require 'yaml'


# Set up the OAuth2 client
def oauth2_client
  OAuth2::Client.new(
    $config['client_id'],
    $config['client_secret'], 
    :site => $config['oauth_server'], 
    :authorize_url =>'/services/oauth2/authorize', 
    :token_url => '/services/oauth2/token',
    :raise_errors => false
  )
end

# Subclass OAuth2::AccessToken so we can do auto-refresh
class AutoRefreshToken < OAuth2::AccessToken
  def request(verb, path, opts={}, &block)
    response = super(verb, path, opts, &block)
    if response.status == 401 && refresh_token
      puts "Refreshing access token"
      @token = refresh!.token
      response = super(verb, path, opts, &block)
    end
    response
  end
end

# Filter for all paths except /oauth/callback
before do
  pass if request.path_info == '/oauth/callback'
  
  token         = session['access_token']
  refresh       = session['refresh_token']
  @instance_url = session['instance_url']
  
  if token
    @access_token = AutoRefreshToken.from_hash(oauth2_client, { :access_token => token, :refresh_token =>  refresh, :header_format => 'OAuth %s' } )
  else
    redirect oauth2_client.auth_code.authorize_url(:redirect_uri => "http://#{request.host}:4567/oauth/callback")
  end  
end

after do
  # Token may have refreshed!
  if @access_token && session['access_token'] != @access_token.token
    puts "Putting refreshed access token in session"
    session['access_token'] = @access_token.token
  end
end

get '/oauth/callback' do
  begin
    access_token = oauth2_client.auth_code.get_token(params[:code], 
      :redirect_uri => "http://#{request.host}:4567/oauth/callback")

    session['access_token']  = access_token.token
    session['refresh_token'] = access_token.refresh_token
    session['instance_url']  = access_token.params['instance_url']
    
    redirect '/'
  rescue => exception
    output = '<html><body><tt>'
    output += "Exception: #{exception.message}<br/>"+exception.backtrace.join('<br/>')
    output += '<tt></body></html>'
  end
end


get '/logout' do
  # First kill the access token
  # (Strictly speaking, we could just do a plain GET on the revoke URL, but
  # then we'd need to pull in Net::HTTP or somesuch)
  @access_token.get($config['oauth_server']+'/services/oauth2/revoke?token='+session['access_token'])
  # Now save the logout_url
  @logout_url = session['instance_url']+'/secur/logout.jsp'
  # Clean up the session
  session['access_token'] = nil
  session['instance_url'] = nil
  session['field_list'] = nil
  # Now give the user some feedback, loading the logout page into an iframe...
  erb :logout
end

get '/revoke' do
  # For testing - revoke the token, but leave it in place, so we can test refresh
  @access_token.get($config['oauth_server']+'/services/oauth2/revoke?token='+session['access_token'])
  puts "Revoked token #{@access_token.token}"
  "Revoked token #{@access_token.token}"
end