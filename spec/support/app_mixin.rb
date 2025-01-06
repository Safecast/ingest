module AppMixin
  def app
    Rack::Builder.parse_file('config.ru')
  end
end
