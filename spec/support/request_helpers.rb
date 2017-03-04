module RequestHelpers
  def parsed_response
    JSON.parse(last_response.body)
  end

  def add_auth(api_key)
    header 'Authorization', api_key
  end

  def remove_auth
    header 'Authorization', nil
  end
end
