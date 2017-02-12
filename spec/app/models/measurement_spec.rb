describe Measurement, type: :model do
  subject { build :measurement }
  it { is_expected.to validate_presence_of :device_id }
end
