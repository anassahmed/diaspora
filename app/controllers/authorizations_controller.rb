class AuthorizationsController < ApplicationController

  rescue_from Rack::OAuth2::Server::Authorize::BadRequest do |e|
    @error = e
    render :nothing => true, :status => e.status
  end

  def new
    @sender_handle = params[:sender_handle]
    @recepient_handle = params[:recepient_handle]
    @time = Time.now.to_i
    @rand = SecureToken.generate
    respond *authorize_endpoint.call(request.env)
  end

  def create
    respond *authorize_endpoint(:allow_approval).call(request.env)
  end

  private

  def respond(status, header, response)
    ["WWW-Authenticate"].each do |key|
      headers[key] = header[key] if header[key].present?
    end
    if response.redirect?
      redirect_to header['Location']
    else
      render :new
    end
  end

  def authorize_endpoint(allow_approval = false)
    Rack::OAuth2::Server::Authorize.new do |req, res|
      @client = Client.first || req.bad_request!
      res.redirect_uri = @redirect_uri = req.verify_redirect_uri!(@client.redirect_uri)
      if allow_approval
        if params[:approve]
          case req.response_type
          when :code
            authorization_code = current_account.authorization_codes.create(:client_id => @client, :redirect_uri => res.redirect_uri)
            res.code = authorization_code.token
          when :token
            access_token = current_account.access_tokens.create(:client_id => @client)
            res.access_token = access_token.token
            res.token_type = :bearer
            res.expires_in = access_token.expires_in
          end
          res.approve!
        else
          req.access_denied!
        end
      else
        @response_type = req.response_type
      end
    end
  end
end