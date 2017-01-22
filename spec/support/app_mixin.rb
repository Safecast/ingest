module AppMixin
  def app
    Rack::Builder.parse_file('config.ru').first
  end
end
