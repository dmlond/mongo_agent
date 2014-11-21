mongo_agent
=================

MongoAgent is a framework for creating distributed pipelines across many different servers, each using the same MongoDB as a control panel.

Description
------------------

MongoAgents are simple processes designed to take a task from a queue, and use information
in the task description to perform a process.  Queues are document stores defined in a
Mongo Database.  Each document in the queue document store is a task.  The task can hold
any information that can be serialized into JSON (moped uses BSON, which is a binary storage
of JSON). Each task must define an 'agent_name' (used by an agent to find its tasks in the queue)
and a 'ready' boolean field(used by the agent to know if the task is ready to be processed).
MongoAgents modify the task document to record lifespan events of the process being applied to
the task.

Interface
------------------

The MongoAgent interface includes three basic methods:

new: this instantiates a MongoAgent.  It must be supplied a name and queue. It can
also be supplied a value for sleep_between.

process!: this method takes a Block as argument, finds the first ready task in the queue,
registers itself to the task, passes the task as argument to the Block, and
then completes or fails the task depending on the return from the Block.
The Block must return a boolean to signal that it succeeded or failed.  It can also
return a Hash to be added to the task document for use by other agents.

work!: this method takes a Block as argument, and continuously calls process! with
that Block, sleeping in between calls. The agent can be configured to stop working
and return by setting the process_while attribute to a Block (see below).  The amount
of time it sleeps between calls can also be configured.

get_tasks:  This method returns tasks in the agent's queue.  By default, it returns
all tasks that are ready: true.  It can also take a Hash that is a valid Mongo query
for documents in the document store for the queue.

Lifespan Events
------------------

The process! method records the following events on the task document as it works:

register: when a MongoAgent starts to process! a task, it updates ready to false,
sets the started_at to the date_time it started, and sets the agent_host to its hostname.

complete: when a MongoAgent successfully performs its process on the task, it updates
complete to true, completed_at to the date_time of completion, and sets error_encountered
to false. A Block can return additional data to be added to the document to inform other
agents, and/or additional tasks to be added to the queue.

fail: when a MongoAgent is not successful in performing its process on the task, it updates
complete to true, completed_at to the date_time of completion, and error_encountered to true.
A Block can return additional data to be added to the document to inform other agents.

process! also updates the log on the agent itself, incrementing 'tasks_processed' each
time the Block is called with the task, and 'failed_tasks' each time the Block
is not successful.

Work Process Control
------------------

The work! method calls the 'process_while' Block, with its log as argument, to
determine whether to continue to process tasks.  The default process_while block
simply returns true each time it is called, so that work! will run indefinitely.
The attribute can be set to a different Block to configure work! to stop processing
for different reasons.  The Block can be defined to accept the agent log hash as
argument, and use it to signal to stop processing depending on the number of tasks that
have been processed, or the number of failures that have been encountered.

```ruby
@agent.process_while = -> (log) {
  if log[:errors_encountered] > 5
    false
  else
    true
  end
}
```

Environment
------------------

MongoAgents use the following Environment variables to connect to and interact with
a MongoDB instance:

MONGO_HOST: host URL for the MongoDB, can be in any form that mongod itself can
use, e.g. host, host:port, etc.

MONGO_DB: the name of the Document Store in the MongoDB to use to find its queue.
it will be created if it does not exist

License
-------

The license of the source is The MIT License (MIT)

Author
------

Darin London
