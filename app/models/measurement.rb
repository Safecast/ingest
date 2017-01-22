class Measurement < ActiveRecord::Base
  validates :captured_at, :location, :device_id, :payload, presence: true
end

# == Schema Information
#
# Table name: measurements
#
#  id          :integer          not null, primary key
#  captured_at :datetime         not null
#  location    :geography({:srid not null, point, 4326
#  device_id   :integer          not null
#  payload     :json             not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
