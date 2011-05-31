require 'sinatra'
require 'mongo'
require 'json'
require 'httparty'
require 'nokogiri'
require 'cgi'
require 'ruby-debug'

$db = Mongo::Connection.new("localhost", 27017)["crunch_profile"]

def parse_title(raw_title)
  case raw_title
  when /^board/i
    "investor"
  when /^director\s?$/i
    "investor"
  when /advisor/i
    "investor"
  when /investor/i
    "investor"
  else
    "employee"
  end
end

def create_graph(depth, entity_permalink, type)
  if type == "person"
    coll = $db["people"]
    coll_invs = "investments"
    coll_entity = "person"
    coll_stock_photo = "http://hyperpublic.com/images/icons/services/person/small.png?1305988916"
    other_coll = $db["companies"]
    other_coll_invs = "funding_rounds"
    other_coll_entity = "firm"
    other_coll_stock_photo = "http://hyperpublic.com/images/icons/public_place/gov/small.png?1305988916"
  elsif type == "firm"
    coll = $db["companies"]
    coll_invs = "funding_rounds"
    coll_entity = "firm"
    coll_stock_photo = "http://hyperpublic.com/images/icons/public_place/gov/small.png?1305988916"
    other_coll = $db["people"]
    other_coll_invs = "investments"
    other_coll_entity = "person"
    other_coll_stock_photo = "http://hyperpublic.com/images/icons/services/person/small.png?1305988916"
  end

  nodes = []
  links = []

  entity = coll.find("permalink" => entity_permalink).first
  @entity = entity

  relationship_entities = other_coll.find("permalink" => {"$in" => entity["relationships"].collect{|rel| rel[other_coll_entity]["permalink"] }}).entries
  relationship_entities.each do |rel_ent|
    links << {"source" => entity["permalink"], "source_type" => coll_entity, "target" => rel_ent["permalink"], "target_type" => other_coll_entity, "link_type" => parse_title(rel_ent["title"])}
  end

  children_permalinks = relationship_entities.collect {|r_e| 
    r_e["relationships"].collect{|rel| 
      if r_e["relationships"]
        links << {"source" => r_e["permalink"], "source_type" => other_coll_entity, "target" => rel[coll_entity]["permalink"], "target_type" => coll_entity, "link_type" => parse_title(rel["title"])}
        rel[coll_entity]["permalink"] 
      end
    }
  }.flatten.compact.uniq

  children_permalinks.delete(entity_permalink)
  children = coll.find("permalink" => {"$in" => children_permalinks}).entries

  children.each do |e|
    image = e["image"]["available_sizes"][0] if e["image"]
    nodes << {"permalink" => e["permalink"], "name" => e["name"] ? e["name"] : "#{e["first_name"]} #{e["last_name"]}", 
              "type" => coll_entity, "image_url" => e["image"] ? "http://www.crunchbase.com/#{e["image"]["available_sizes"][0][1]}" : coll_stock_photo,
              "image_ratio" => image ? (image[0][0].to_f / image[0][1].to_f) : 1}
  end

  relationship_entities.each do |e|
    image = e["image"]["available_sizes"][0] if e["image"]
    e_hash = {"permalink" => e["permalink"], "name" => e["name"] ? e["name"] : "#{e["first_name"]} #{e["last_name"]}", 
              "type" => other_coll_entity, "image_url" => image ? "http://www.crunchbase.com/#{image[1]}" : other_coll_stock_photo,
              "image_ratio" => image ? (image[0][0].to_f / image[0][1].to_f) : 1 }
    e_hash["twitter_username"] = e["twitter_username"] if other_coll_entity == "person" && e["twitter_username"]
    nodes << e_hash
  end

  nodes.each do |n|
    area = 900 + [10000 - 900 - nodes.count * (10000 - 900) / 80, 0].max
    n["image_width"], n["image_height"] = dimensions_by_area(area, n["image_ratio"])
    #n["image_height"] = 30 + [(40 - nodes.count), 0].max
    #n["image_width"] = n["image_height"] * n["image_ratio"]
  end

  entity_hash = {"permalink" => entity["permalink"], 
                "name" => entity["name"] ? entity["name"] : "#{entity["first_name"]} #{entity["last_name"]}", 
                "type" => coll_entity, "image_url" => entity["image"] ? "http://www.crunchbase.com/#{entity["image"]["available_sizes"][0][1]}" : coll_stock_photo, 
                "image_ratio" => entity["image"] ? (entity["image"]["available_sizes"][0][0][0].to_f / entity["image"]["available_sizes"][0][0][1].to_f) : 1}

  entity_hash["image_width"], entity_hash["image_height"] = dimensions_by_area(4900 + [22500 - 4900 - nodes.count * (22500 - 4900) / 80, 0].max, entity_hash["image_ratio"])
  #entity_hash["image_height"] = 70 + [(80 - 1.5 * nodes.count), 0].max
  #entity_hash["image_width"] = entity_hash["image_height"] * entity_hash["image_ratio"]

  entity_hash["twitter_username"] = entity["twitter_username"] if coll_entity = "person" && entity["twitter_username"]
  nodes << entity_hash
  if nodes.count < 150
    {:nodes => nodes, :links => links }
  else
    {:error => "too many nodes"}
  end

=begin
  if depth == 1
    :nodes => entity["edges"].collect{|e| {:permalink => e["permalink"], :image_url => e["image"][} + permalink
    :links => entity["edges"].collect{|e| :source => permalink, :target => e["permalink"]}
  else
    child_edges = entity["edges"].collect do |edge|
      create_graph(depth - 1, edge["permalink"]
    end.flatten.compact

    child_edges + entity["edges"]
  end
=end
end

def dimensions_by_area(area, ratio)
  width = Math.sqrt(area.to_f * ratio.to_f)
  height = width / ratio
  [width, height]
end

def process_graph!(graph)
  #paginate(graph, 1, 90)
  permalinks = graph[:nodes].collect{|n| n["permalink"]}
  graph[:links].each do |link|
    link["source"] = permalinks.index(link["source"])
    link["target"] = permalinks.index(link["target"])
  end
  graph[:links].delete_if{|l| !l["source"] || !l["target"]}
end

def get_connections(graph, permalink)

end

def hunch_compatibility(tuples)
  handles = tuples.keys
  return nil if handles.compact.empty?

  unfrozen_handles = handles.collect do |h|
    "tw_" + h
  end

  url = "http://api.hunch.com/api/v1/get-tastemates/?user_id=tw_ericxtang&user_ids=#{unfrozen_handles.join("%2C")}&topic_ids=list_magazine%2Ccat_tech%2Ccat_art-design%2Ccat_business-office%2Ccat_culture-humanities%2Ccat_education-career&limit=#{handles.count}"
  response = HTTParty.get(url)
  results = response.parsed_response["tastemates"]

  results_with_handle = results.collect do |r| 
    #doc = Nokogiri.HTML(HTTParty.get(r["url"]).response.body)
    #handle = doc.css(".screen-name.pill").text
    url = "http://api.twitter.com/1/users/show.json?user_id=#{r["user_id"].gsub("tw_", "")}"
    response = HTTParty.get(url)
    handle = JSON.parse(response.body)["screen_name"]
    {"score" => r["score"], "handle" => "tw_" + handle.to_s, "name" => tuples[handle.to_s]}
  end

  results_with_handle
end

def paginate(graph, page_num, page_size)
  if graph[:nodes].count > page_num * page_size
    graph[:nodes].shuffle!
    new_nodes = graph[:nodes][(page_num * page_size)..((page_num + 1) * page_size)]
    permalinks = new_nodes.collect {|n| n["permalink"]}
    new_edges = graph[:links].collect {|e| e if permalinks.include?(e["source"]) && permalinks.include?(e["target"])}.compact
    graph[:nodes] = new_nodes
    graph[:links] = new_edges
  end
end

def search
  if (user = $db["people"].find(:first_name => /^#{params["q"].split(" ")[0]}$/i, :last_name => /^#{params["q"].split(" ")[1]}$/i).first)
    entity = user
    entity_type = "person"
  elsif company = $db["companies"].find(:name => /^#{params["q"]}$/i).first
    entity = company
    entity_type = "firm"
  end

  params["type"] = entity_type
  params["permalink"] = entity["permalink"] if entity

  entity
end

get /graph/ do
  if params["q"]
    entity = search   
    return nil if !entity
  end

  graph = {}
  if params["type"] == "person"
    graph = create_graph(1, params["permalink"], "person")
    process_graph!(graph) if graph[:nodes] && graph[:links]
  elsif params["type"] == "firm"
    graph = create_graph(1, params["permalink"], "firm")
    process_graph!(graph) if graph[:nodes] && graph[:links]
  else
  end

  do_hunch = true
  if do_hunch
    if params["type"] == "person"
      hunch_score = hunch_compatibility({@entity["twitter_username"] => "#{@entity["first_name"]} #{@entity["last_name"]}"}) if @entity["twitter_username"] && !@entity["twitter_username"].empty?
      @hunch = [{"score" => ((hunch_score[0]["score"] / 0.3191730351337474) * 100).to_i, "name" => @entity["name"]}] if hunch_score
    else
=begin
      tuples = {}
      graph[:nodes].each { |n| 
        tuples[n["twitter_username"]] = "#{n["name"]}" if n["twitter_username"] && !n["twitter_username"].empty?
      }.compact
      hunch_score = hunch_compatibility(tuples)
      @hunch = hunch_score.each {|hs| hs["score"] = ((hs["score"] / 0.3191730351337474) * 100).to_i}
=end
    end
  end
  @graph = graph
  erb :graph
end

get /company/ do

end

get /person/ do

end

get /test/ do
  content_type :json
  hunch_compatability(["tw_ericxtang"]).to_json
end
