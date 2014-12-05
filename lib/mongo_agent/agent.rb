require 'moped'

module MongoAgent

# @note The license of this source is "MIT Licence"

# MongoAgent::Agent is designed to make it easy to create an agent that works on tasks
# queued up in a specified queue.  A task is a document in a queue defined in
# the MONGO_HOST MONGO_DB.  A task must be created by another agent (MongoAgent::Agent,
# or Human) in the queue.  It must have, at minimum, the following fields:
#  agent_name: string, name of the agent that should process the task
#  ready: must be true for an agent to process the task
# When the agent finds a ready task for its agent_name, it registers itself with the
# task document by updating its agent_host field to the host that is running the
# agent, and sets ready to false (meaning it is actually running).  When the agent
# completes the task, it sets the complete flag to true.  If the agent encounters
# an error during processing, it can signal failure by setting the error_encountered
# field to true at the time its complete flag is updated to true.
#
# When an Agent creates a task, it can pass a variety of messages as JSON in the task
# that can be used by the processing agent.  The processing agent can also pass a
# variety of messages to other agents when they review the task.  These messages
# are just fields added to the task Document when it is created or updated by
# an agent.
# Any MongoAgent::Agent depends on the following environment variables to configure its
# MongoDB connection:
#   MONGO_HOST: host URL for the MongoDB, can be in any form that mongod itself can
#               use, e.g. host, host:port, etc.
#   MONGO_DB: the name of the Document store in the MongoDB to use to find its queue.
#             it will be created if it does not exist

# @author Darin London Copyright 2014
  class Agent

# This holds the Moped::Session object that can be used to query information from the MongoDB
#   hosted by the MONGO_HOST environment variable
# @return [Moped::Session]
    attr_reader :db

# This holds the log while work! is running
#    log will be a Hash with the following keys:
#      tasks_processed: int number of tasks processed (success of failure)
#      failed_tasks: int number of tasks that have failed
#    The log is passed to the block that is assigned to process_while (see below)
# @return [Hash]
    attr_reader :log

#  This holds a block that will be passed the log as an argument and return true
#    as long as the agent should continue to process tasks when work! is called,
#    and false when work! should stop and return.
#    If not set, the agent will continue to process tasks until it is killed when
#    work! is called
#  @return [Block]
    attr_accessor :process_while

# The name of the agent for which tasks will be taken from the queue
# @return [String]
    attr_accessor :name

# The name of the task queue that contains the tasks on which this agent will work.
# @return [String]
    attr_accessor :queue

# number of seconds to sleep between each call to process! when running agent.work! or agent.process_while
# default 5
    attr_accessor :sleep_between

# create a new MongoAgent::Agent
# @param attributes [Hash] with name, queue, and optional sleep_between
# @option attributes [String] name REQUIRED
# @option attributes [String] queue REQUIRED
# @option attributes [Int] sleep_between OPTIONAL
# @raise [MongoAgent::Error] name and queue are missing
    def initialize(attributes = nil)
      if attributes.nil?
        raise MongoAgent::Error, "attributes Hash required with name and queue keys required"
      end
      @name = attributes[:name]
      @queue = attributes[:queue]
      unless @name && @queue
        raise MongoAgent::Error, "attributes[:name] and attributes[:queue] are required!"
      end
      build_db()
      if attributes[:sleep_between]
        @sleep_between = attributes[:sleep_between]
      else
        @sleep_between = 5
      end
      @log = {
         tasks_processed: 0,
         failed_tasks: 0
      }
      @process_while = ->(log) { true }
    end

# If a task for the agent is found that is ready, process! registers itself with the task
# by setting ready to false, and setting its hostname on the :agent_host field, and then
# passes the task to the supplied block. This block must return a required boolean field
# indicating success or failure, and an optional hash of key - value fields that will be
# updated on the task Document.  Note, the updates are made regardless of the value of
# success. In fact, the agent can be configured to update different fields based on
# success or failure.   Also, note that any key, value supported by JSON can be stored
# in the hash. This allows the agent to communicate any useful information to the task
# for other agents (MongoAgent::Agent or human) to use. The block must try at all costs
# to avoid terminating. If an error is encountered, block should return false for the
# success field to signal that the process failed.  If no errors are encountered block
# should return true for the success field.
#
# @example Exit successfully and sets :complete to true on the task
#   @agent->process! do |task_hash|
#     foo = task_hash[:foo]
#     # do something with foo to perform a task
#     true
#   end
#
# @example Same, but also sets the 'files_processed' field
#   @agent->process! { |task_hash|
#     # ... operation using task_hash for information
#     [true, {:files_processed => 30}]
#   }
#
# @example Fails, sets :complete to true, and :error_encountered to true
#   @failure = ->(task_hash){
#     begin
#       # ... failing operation using task_hash for information
#       return true
#     rescue
#      return false
#     end
#   }
#
#   @agent->process!(&@failure)
#
# @example Same, but also sets the 'notice' field
#   @agent->process! do |task_hash|
#     ...
#     [false, {:notice => 'There were 10 files left to process!' }]
#   end
#
# @example This agent passes different parameters based on success or failure
#   $agent->process! { |task_hash|
#     # ... process and set $success true or false
#     if $success
#       [ $success, {:files_processed => 100} ]
#     else
#       [ $success, {:files_remaining => 10}]
#     end
#   }
#
# @param agent_code [Block, Lambda, or Method] Code to process a task
# @yieldparam Task [Hash]
# @yieldreturn [Boolean, Hash] success, (optional) hash of fields to update and values to update on the task
    def process!(&agent_code)
      (runnable, task) = register()
      return unless runnable
      (success, update) = agent_code.call(task)
      @log[:tasks_processed] += 1
      if success
        complete_task(task, update)
      else
        fail_task(task, update)
      end
      return
    end

# Iteratively runs process! on the supplied Block, then sleeps :sleep_between
# between each attempt.  Block should match the specifications of what can
# be passed to process! (see above).
#
# If @process_while is set to a Block, Lambda, or Method, then it is called after
#  each task is processed, and passed the current @log.  As long as the
#  Block returns true, work! will continue to process.  work! will stop processing
#  tasks when the Block returns false.
#
# @example process 3 entries and then exit
#   @agent.process_while = ->(log) {
#     (log[:tasks_processed] < 3)
#   }
#   @agent.work! { |task_hash|
#     #... do something with task_hash and return true of false just as in process!
#   }
#
# @example process until errors are encountered and then exit
#   @agent.process_while = ->(log) {
#     not(log[:errors_encountered])
#   }
#   @agent.work! { |task_hash|
#     #... do something with task_hash and return true of false just as in process!
#   }
#   $stderr.puts " #{ @agent.log[:errors_encountered ] } errors were encountered during work."
# @param agent_code [Block, Lambda, or Method] Code to process a task
# @yieldparam Task Hash
# @yieldreturn [Boolean, Hash] success, (optional) hash of fields to update and values to update on the task
    def work!(&agent_code)

      while (@process_while.call(@log))
        process!(&agent_code)
        sleep @sleep_between
      end
    end

# get A MONGO_DB[queue] Moped::Query, either for the specified query Hash, or, when
# query is nil, all that are currently ready for the @name.  This can be used to
# scan through the tasks on the @queue to perform aggregation tasks:
# @example collecting information
#   @agent->get_tasks({
#      agent_name: @agent->name,
#      error_encountered: true
#   }).each do |task|
#     $stderr.puts "ERROR:\n#{ task.inspect }\n"
#   end
#
# @example update ready to true for tasks that need intervention before they can run
#   @agent->get_tasks({
#      agent_name: @agent->name,
#      waiting_for_information: true
#   }).each do |task|
#     task.update('$set' => {ready: true, waiting_form_information: false})
#   end
#
# @param query [Hash] (optional) any query to find tasks
# @return [Moped::Query]
    def get_tasks(query = nil)
      if query.nil?
        return @db[@queue].find({agent_name: @name, ready: true})
      else
        return @db[@queue].find(query)
      end
    end

    private

    def register
      task = get_tasks().first
      unless task
        $stderr.puts "there are no ready tasks for #{@name} in queue #{@queue}"
        return false
      end

      hostname = Socket.gethostname
      get_tasks({ _id: task[:_id] }).update('$set' => {ready: false, agent_host: "#{hostname}", started_at: Time.now })
      return true, task
    end

    def complete_task(task, update = nil)
      if update.nil?
        update = {}
      end
      update[:complete] = true
      update[:error_encountered] = false
      update[:completed_at] = Time.now
      get_tasks({ _id: task[:_id] }).update('$set' => update)
    end

    def fail_task(task, update = nil)
      @log[:failed_tasks] += 1
      if update.nil?
        update = {}
      end
      update[:complete] = true
      update[:completed_at] = Time.now
      update[:error_encountered] = true
      get_tasks({ _id: task[:_id] }).update('$set' => update)
    end

    def build_db
      @db = Moped::Session.new([ ENV['MONGO_HOST'] ])
      @db.use ENV['MONGO_DB']
    end

  end #MongoAgent::Agent
end #MongoAgent
