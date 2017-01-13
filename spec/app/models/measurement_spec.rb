describe Measurement, type: :model do
  subject { build :measurement }
  it { is_expected.to validate_presence_of :captured_at }
  it { is_expected.to validate_presence_of :device_id }
  it { is_expected.to validate_presence_of :location }
  it { is_expected.to validate_presence_of :payload }
end
