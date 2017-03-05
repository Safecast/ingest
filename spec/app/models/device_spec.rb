describe Device, type: :model do
  subject { build :device }

  it { is_expected.to validate_presence_of :device_type }
end
