class Measurement < ActiveRecord::Base
  validates :device_id, presence: true
end

# == Schema Information
#
# Table name: measurements
#
#  id          :integer          not null, primary key
#  captured_at :datetime
#  location    :geography({:srid point, 4326
#  device_id   :integer          not null
#  payload     :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
