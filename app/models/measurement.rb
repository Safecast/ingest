class Measurement < ActiveRecord::Base
  # XXX: Update created_at and updated_at in PostgreSQL
  self.record_timestamps = false

  validates :device_id, presence: true
  validate :must_be_unique

  def must_be_unique
    if self.class.exists?(["payload - 'net_transport' - 'when_uploaded' = ?", payload_for_uniqueness.to_json])
      errors.add(:payload, 'Must be unique')
    end
  end

  def payload_for_uniqueness
    payload.except('net_transport', 'when_uploaded')
  end
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
#
