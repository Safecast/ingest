class Device < ActiveRecord::Base
  has_many :measurements

  validates :payload, presence: true
  validates :device_type, presence: true

  AVAILABLE_TYPES = ['pointcast', 'solarcast', 'bgeigie'].freeze

  def self.available_types
    AVAILABLE_TYPES
  end
end

# == Schema Information
#
# Table name: devices
#
#  numeric_id    :integer          not null
#  location      :geography({:srid point, 4326
#  location_name :string
#  payload       :jsonb            not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  id            :uuid             not null, primary key
#  device_type   :string
#
