module Authentication
  extend Grape::API::Helpers

  def authenticate!
    error!('Unauthorized', 401) unless authenticated?(headers['Authorization'])
  end

  private

  def authenticated?(auth_header)
    auth_header && auth_header == Config.api_key
  end
end
