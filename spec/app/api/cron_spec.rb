describe API::Cron, type: :api do
  context 'POST /cron' do
    before do
      API::Cron.script_location = Config.root.join('spec', 'support', 'cron')
      API::Cron.cron_definitions = Config.root.join('spec', 'support', 'cron', 'cron.yaml')
    end

    context 'basic post' do
      let(:job_name) { 'test_csv_dump' }

      before do
        header 'X-Aws-Sqsd-Taskname', job_name
        post '/cron'
      end

      it 'runs the given script' do
        expect(last_response.status).to eq(200)
        last_ran = File.read(API::Cron.script_location.join(job_name+'.last')).to_i
        expect(last_ran).to be_within(10).of(Time.now.to_i)
      end
    end

    context 'not listed job' do
      let(:job_name) { 'not_on_the_whitelist' }

      before do
        header 'X-Aws-Sqsd-Taskname', job_name
        post '/cron'
      end

      it 'is forbidden' do
        expect(last_response.status).to eq(403)
      end
    end


    context 'not from local host' do
      let(:job_name) { 'test_csv_dump' }

      before do
        header 'X-Aws-Sqsd-Taskname', job_name
        post '/cron', {}, { 'REMOTE_ADDR' => '192.168.1.1' }
      end

      it 'is forbidden' do
        expect(last_response.status).to eq(403)
      end
    end
  end
end
