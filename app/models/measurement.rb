class Measurement < ActiveRecord::Base
  # XXX: Update created_at and updated_at in PostgreSQL
  self.record_timestamps = false

  validates :device_id, presence: true
end

# == Schema Information
#
# Table name: measurements
#
#  id         :integer          not null, primary key
#  device_id  :integer          not null
#  payload    :jsonb            not null
#  created_at :datetime
#  updated_at :datetime
#  device_urn :string
#
