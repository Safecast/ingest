class Device < ActiveRecord::Base
  validates :payload, presence: true

  class << self
    def valid_attributes
      @valid_attributes ||= Set.new(%i(id longitude latitude location_name))
    end
  end
end

# == Schema Information
#
# Table name: devices
#
#  id            :integer          not null, primary key
#  location      :geography({:srid point, 4326
#  location_name :string
#  payload       :jsonb            not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
