require 'spec_helper'

RSpec.describe Workers::S3Raw do
  describe '#work' do
    before do
      expect(::Aws::S3::Bucket).to receive(:new).and_wrap_original do |m, (url)|
        m.call(url, client: ::Aws::S3::Client.new(stub_responses: true))
      end

      expect(::Aws::SQS::Queue).to receive(:new).and_wrap_original do |m, (url)|
        m.call(url, client: client)
      end
    end

    let(:worker) { described_class.new('http://exapmle.com/', 'output_bucket', 'prefix') }

    context 'empty queue' do
      let(:client) { ::Aws::SQS::Client.new(stub_responses: true) }

      it { expect { worker.work }.to output(/No messages to process/).to_stdout }
    end

    context 'one message in queue' do
      let(:client) do
        ::Aws::SQS::Client.new(stub_responses: {
          receive_message: [{ messages: [{ body: '{"Message":"Hello"}', receipt_handle: 'hnd' }] }, { messages: [] }]
        })
      end

      it { expect { worker.work }.to output(/Batching 1 messages/).to_stdout }
    end
  end
end