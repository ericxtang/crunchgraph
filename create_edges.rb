require 'mongo'
require 'ruby-debug'

$db = Mongo::Connection.new("localhost", 27017)["crunch_profile"]


def get_person_edges(p)
  return nil if !p["relationships"]

  edges = p["relationships"].collect do |company|
    next if !company["firm"] || !(permalink = company["firm"]["permalink"])
    company = $db["companies"].find("permalink" => permalink).first
    next if !company || !company["relationships"]

    people = company["relationships"].collect do |person|
      company_info = {"company" => {:image => company["image"], :name => company["name"], :homepage_url => company["homepage_url"], :permalink => company["permalink"]}}
      if person["person"]["permalink"] != p["permalink"]
        person["person"].merge(company_info) 
      else
        nil
      end
    end.compact
  end.flatten.compact
end

def graph_people
  $db["people"].find().each do |p|
    edges = get_person_edges(p)
    p["edges"] = edges if edges
    $db["people"].save(p)
=begin
    next unless p["relationships"]
    p["relationships"].each do |company|
      if company["firm"] && (permalink = company["firm"]["permalink"])
        company = $db["companies"].find("permalink" => permalink).first
        if company && company["relationships"]
          edges = company["relationships"].collect do |person|
            company_info = {"company" => {:image => company["image"], :name => company["name"], :homepage_url => company["homepage_url"], :permalink => company["permalink"]}}
            if person["permalink"] != permalink
              person.merge(company_info) 
            else
              nil
            end
          end
          p["edges"] = edges
          $db["people"].save(p)
        end
      end
    end
=end
  end
end


def get_company_edges(c)
  return nil if !c["relationships"]

  edges = c["relationships"].collect do |person|
    next if !person["person"] || !(permalink = person["person"]["permalink"])
    person = $db["people"].find({"permalink" => permalink}).first
    next if !person || !person["relationships"]

    edges = person["relationships"].collect do |company|
      person_info = {"person" => {"image" => person["image"], "first_name" => person["first_name"], "last_name" => person["last_name"], "permalink" => person["permalink"]}}
      if company["firm"]["permalink"] != c["permalink"]
        company["firm"].merge(person_info)
      else
        nil
      end
    end.compact
  end.flatten.compact
end

def graph_companies
  $db["companies"].find().each do |c|
    edges = get_company_edges(c)
    c["edges"] = edges if edges
    $db["companies"].save(c)
  end

=begin
    next unless c["relationships"]
    c["relationships"].each do |person|
      if person["person"] && (permalink = person["person"]["permalink"])
        person = $db["people"].find("permalink" => permalink).first
        if person && person["relationships"]
          edges = person["relationships"].collect do |company|
            person_info = {"person" => {:image => person["image"], :first_name => person["first_name"], :last_name => person["last_name"], :permalink => person["permalink"]}}
            if company["permalink"] != permalink
              company.merge(person_info)
            else
              nil
            end
          end
          c["edges"] = edges
          $db["companies"].save(c)
        end
      end
    end
=end
end

#graph_people
graph_companies
