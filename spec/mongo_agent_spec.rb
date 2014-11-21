require 'mongo_agent'
require 'moped'
require 'psych'
require 'socket'

RSpec.describe "MongoAgent::Agent" do
  let (:test_agent_name) { 'test_agent' }
  let (:test_agent_queue) { 'testqueue' }
  let (:test_agent_sleep_between) { 10 }
  let (:expected_default_sleep_between) { 5 }
  let (:test_task_params) {[
    'foo',
    'bar',
    'baz',
    'bleb'
  ]}
  let (:expected_hostname) { Socket.gethostname }
  before (:each) do
    @db = Moped::Session.new([ ENV['MONGO_HOST'] ])
    @db.use ENV['MONGO_DB']
  end

  after (:each) do
    @db.drop
  end

  context "initialization" do
    it "throws MongoAgent::Error without an attributes Hash" do
      expect {
        MongoAgent::Agent.new
      }.to raise_error { |error|
        expect(error).to be_a(MongoAgent::Error)
      }
    end

    it "throws MongoAgent::Error without attributes[:name]" do
      expect {
        MongoAgent::Agent.new({queue: test_agent_queue})
      }.to raise_error { |error|
        expect(error).to be_a(MongoAgent::Error)
      }
    end

    it 'throws MongoAgent::Error without attributes[:queue]' do
      expect {
        MongoAgent::Agent.new({ name: test_agent_name })
      }.to raise_error { |error|
        expect(error).to be_a(MongoAgent::Error)
      }
    end

    it 'creates MongoAgent::Agent with default sleep_between when provided a name and queue' do
      expect {
        @agent = MongoAgent::Agent.new({
          name: test_agent_name,
          queue: test_agent_queue
        })
      }.to_not raise_error
      expect(@agent.sleep_between).to eq(expected_default_sleep_between)
    end

    it 'allows optional attributes[:sleep_between]' do
      expect {
        @agent = MongoAgent::Agent.new({
          name: test_agent_name,
          queue: test_agent_queue,
          sleep_between: test_agent_sleep_between
        })
      }.to_not raise_error
      expect(@agent.sleep_between).to eq(test_agent_sleep_between)
    end
  end #initialization

  context "process!" do
    subject {
      MongoAgent::Agent.new({
        name: test_agent_name,
        queue: test_agent_queue
      })
    }

    context "with no tasks in queue" do
      it 'returns without processing any tasks' do
        called = false
        subject.process! {
          called = true
          true
        }
        expect(called).to eq(false)
        expect(subject.log[:tasks_processed]).to eq(0)
        expect(subject.log[:failed_tasks]).to eq(0)
      end
    end # with no tasks in queue

    context "with no ready tasks in queue" do
      before(:each) do
        @db[test_agent_queue].insert( test_task_params.collect{|param|
          {agent_name: test_agent_name, test_param: param}
        })
      end

      it 'return without processing any tasks' do
        called = false
        subject.process! {
          called = true
          true
        }
        expect(called).to eq(false)
        expect(subject.log[:tasks_processed]).to eq(0)
        expect(subject.log[:failed_tasks]).to eq(0)
      end
    end # with no ready tasks in queue

    context "with ready tasks" do
      before (:each) do
        @db[test_agent_queue].insert( test_task_params.collect{|param|
          {agent_name: test_agent_name, ready: true, test_param: param}
        })
      end

      context "success" do
        context "default" do
          it 'updates complete, started_at, completed_at, and agent_host but not :error_encountered' do
            called = false
            processed_param = nil
            subject.process! { |task|
              processed_param = task[:test_param]
              called = true
              true
            }
            expect(processed_param).to be
            expect(test_task_params.include?(processed_param)).to eq(true)
            expect(called).to eq(true)
            expect(subject.log[:tasks_processed]).to eq(1)
            expect(subject.log[:failed_tasks]).to eq(0)
            processed_task = @db[test_agent_queue].find(
            {agent_name: test_agent_name, test_param: processed_param}
            ).first
            expect(processed_task).to be
            expect(processed_task[:complete]).to eq(true)
            expect(processed_task[:started_at]).to be
            expect(processed_task[:completed_at]).to be
            expect(processed_task[:error_encountered]).to eq(false)
            expect(processed_task[:ready]).to eq(false)
            expect(processed_task[:agent_host]).to eq(expected_hostname)
          end
        end #default

        context "with update" do
          it 'updates complete, started_at, completed_at, agent_host, and update params, but not error_encountered' do
            called = false
            processed_param = nil
            subject.process! { |task|
              processed_param = task[:test_param]
              called = true
              [true, {test_update: 'updated'}]
            }
            expect(processed_param).to be
            expect(test_task_params.include?(processed_param)).to eq(true)
            expect(called).to eq(true)
            expect(subject.log[:tasks_processed]).to eq(1)
            expect(subject.log[:failed_tasks]).to eq(0)
            processed_task = @db[test_agent_queue].find(
            {agent_name: test_agent_name, test_param: processed_param}
            ).first
            expect(processed_task).to be
            expect(processed_task[:complete]).to eq(true)
            expect(processed_task[:started_at]).to be
            expect(processed_task[:completed_at]).to be
            expect(processed_task[:error_encountered]).to eq(false)
            expect(processed_task[:ready]).to eq(false)
            expect(processed_task[:agent_host]).to eq(expected_hostname)
            expect(processed_task[:test_update]).to be
            expect(processed_task[:test_update]).to eq('updated')
          end
        end #with update
      end #success

      context "failure" do
        context "default" do
          it 'updates complete, started_at, completed_at, agent_host, and error_encountered' do
            called = false
            processed_param = nil
            subject.process! { |task|
              processed_param = task[:test_param]
              called = true
              false
            }
            expect(processed_param).to be
            expect(test_task_params.include?(processed_param)).to eq(true)
            expect(called).to eq(true)
            expect(subject.log[:tasks_processed]).to eq(1)
            expect(subject.log[:failed_tasks]).to eq(1)
            processed_task = @db[test_agent_queue].find(
            {agent_name: test_agent_name, test_param: processed_param}
            ).first
            expect(processed_task).to be
            expect(processed_task[:complete]).to eq(true)
            expect(processed_task[:started_at]).to be
            expect(processed_task[:completed_at]).to be
            expect(processed_task[:error_encountered]).to eq(true)
            expect(processed_task[:ready]).to eq(false)
            expect(processed_task[:agent_host]).to eq(expected_hostname)
          end
        end #default

        context "with update" do
          it 'updates complete, started_at, completed_at, agent_host, update params, and error_encountered' do
            called = false
            processed_param = nil
            subject.process! { |task|
              processed_param = task[:test_param]
              called = true
              [false, {test_update: 'updated'}]
            }
            expect(processed_param).to be
            expect(test_task_params.include?(processed_param)).to eq(true)
            expect(called).to eq(true)
            expect(subject.log[:tasks_processed]).to eq(1)
            expect(subject.log[:failed_tasks]).to eq(1)
            processed_task = @db[test_agent_queue].find(
            {agent_name: test_agent_name, test_param: processed_param}
            ).first
            expect(processed_task).to be
            expect(processed_task[:complete]).to eq(true)
            expect(processed_task[:started_at]).to be
            expect(processed_task[:completed_at]).to be
            expect(processed_task[:error_encountered]).to eq(true)
            expect(processed_task[:ready]).to eq(false)
            expect(processed_task[:agent_host]).to eq(expected_hostname)
            expect(processed_task[:test_update]).to be
            expect(processed_task[:test_update]).to eq('updated')
          end
        end #with update
      end #failure
    end # with ready tasks
  end #process!

  context "work!" do
    subject {
      MongoAgent::Agent.new({
        name: test_agent_name,
        queue: test_agent_queue
      })
    }

    context "with no tasks in queue" do
      before (:each) do
        @attempts = 0
        subject.process_while = -> (log) {
          @attempts += 1
          ( @attempts < 4 )
        }
      end

      it 'returns without processing any tasks' do
        called = false
        subject.work! {
          called = true
          true
        }
        expect(called).to eq(false)
        expect(subject.log[:tasks_processed]).to eq(0)
        expect(subject.log[:failed_tasks]).to eq(0)
      end
    end # with no ready tasks

    context "with no ready tasks in queue" do
      before (:each) do
        @db[test_agent_queue].insert( test_task_params.collect{|param|
          {agent_name: test_agent_name, test_param: param}
        })
        @attempts = 0
        subject.process_while = -> (log) {
          @attempts += 1
          ( @attempts < 4 )
        }
      end

      it 'returns without processing any tasks' do
        called = false
        subject.work! {
          called = true
          true
        }
        expect(called).to eq(false)
        expect(subject.log[:tasks_processed]).to eq(0)
        expect(subject.log[:failed_tasks]).to eq(0)
      end
    end # with no ready tasks in queue

    context "with ready tasks" do
      before (:each) do
        @db[test_agent_queue].insert( test_task_params.collect{|param|
          {agent_name: test_agent_name, ready: true, test_param: param}
        })
        subject.process_while = -> (log) {
          (log[:tasks_processed] < 2)
        }
      end

      it "will process! until process_while returns false" do
        called = 0
        subject.work! {
          called += 1
          true
        }
        expect(called).to eq(2)
        expect(subject.log[:tasks_processed] < 2).to eq(false)
        expect(subject.log[:tasks_processed]).to eq(2)
        expect(subject.log[:failed_tasks]).to eq(0)
      end
    end # with ready tasks
  end #work

  context "get_tasks" do
    let (:error_document) {{
      agent_name: test_agent_name,
      test_param: 'finished',
      agent_host: 'daaedcedddeaaf',
      test_param: 'failed_entry',
      complete: true,
      ready: false,
      errors_encounterd: true
    }}

    subject {
      MongoAgent::Agent.new({
        name: test_agent_name,
        queue: test_agent_queue
      })
    }

    before (:each) do
      @db[test_agent_queue].insert( test_task_params.collect{|param|
        {agent_name: test_agent_name, ready: true, test_param: param}
      })
      @db[test_agent_queue].insert(error_document)
    end

    it "returns all ready tasks in queue by default" do
      tasks = subject.get_tasks
      expect(tasks.count).to eq(test_task_params.count)
      tasks.each do |task|
        expect(task[:ready]).to eq(true)
      end
    end

    it "return only tasks that match the query provided" do
      tasks = subject.get_tasks({agent_name: test_agent_name, agent_host: error_document[:agent_host]})
      expect(tasks.count).to eq(1)
      returned_task = tasks.first
      returned_task.keys.each do |key|
        if error_document.keys.include? key
          expect(returned_task[key]).to eq(error_document[key])
        end
      end
    end
  end #get_task

end #MongoAgentTest::Agent
