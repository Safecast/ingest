class Device < ActiveRecord::Base
  validates :payload, presence: true
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
