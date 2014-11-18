require 'mongo_agent/agent'
require 'mongo_agent/error'
require 'socket'

# @note The license of this source is "MIT Licence"
# A Distributed Agent System using MongoDB
#
# MongoAgent is a framework for creating massively distributed pipelines
# across many different servers, each using the same MongoDB as a
# control panel.  It is extensible, and flexible.  It doesnt specify what
# goals any pipeline should be working towards, or which goals are prerequisites
# for other goals, but it does provide logic for easily defining these relationships
# based on your own needs.  It does this by providing a subsumption architecture,
# whereby many small, highly focused agents are written to perform specific goals,
# and also know what resources they require to perform them.  Agents can be coded to
# subsume other agents upon successful completion.  In addition, it is
# designed from the beginning to support the creation of simple human-computational
# workflows.
#
# MongoAgent requires MongoDB and Moped
# @version 0.01
# @author Darin London Copyright 2014
module MongoAgent
end
