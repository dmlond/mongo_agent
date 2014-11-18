require 'moped'

module MongoAgent

# MongoAgent::Db is a class that is meant to be extended by MongoAgent classes.  It
# stores shared code to instantiate and provide access to a MongoDB Document Store and
# Moped::Session object for use by the extending classes to access their MongoDB Document Store
#
# It depends on the following environment variables to configure its MongoDB connect:
#   MONGO_HOST: host URL for the MongoDB, can be in any form that mongod itself can
#               use, e.g. host:port, etc.
#   MONGO_DB: the name of the Document store in the MongoDB to use for all activities
#             will be created if does not exist

  class Db

# This holds the Moped::Session object that can be used to query information from the MongoDB
#   hosted by the MONGO_HOST environment variable
    attr_reader :db

# This is for internal use by SpreadsheetAgent classes that extend SpreadsheetAgent::Db
    def build_db
      @db = Moped::Session.new([ ENV['MONGO_HOST'] ])
      @db.use ENV['MONGO_DB']
    end
  end
end
