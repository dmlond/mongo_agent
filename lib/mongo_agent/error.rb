module MongoAgent

# MongoAgent::Error is an extension of Error that SpreadsheetAgent classes throw
# when critical errors are encountered
  class Error < RuntimeError
  end

end
