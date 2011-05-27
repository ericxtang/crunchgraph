require 'mongo'

db = Mongo::Connection.new("localhost", 27017)["crunch_profile"]

db["companies"].find.each do |c|
  if c["_id"] != c["permalink"]
    db["companies"].remove(c)
  elsif c["_id"] = c["permalink"]
    db["companies"].save(c)
  end
end
