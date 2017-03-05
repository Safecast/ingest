class Measurement < ActiveRecord::Base
  belongs_to :device, :primary_key => 'numeric_id'

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
#  created_at  :datetime
#  updated_at  :datetime
#
