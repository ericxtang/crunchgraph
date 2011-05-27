require 'mongo'
require 'nokogiri'
require 'HTTParty'
require 'ruby-debug'

$queries = "a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z,other".split(",")
$db = Mongo::Connection.new("localhost", 27017)["crunch_profile"]

def get_people
  $queries.each do |q|
    puts "crawling #{q}"
    begin
      doc = Nokogiri::HTML(HTTParty.get("http://www.crunchbase.com/people?c=#{q}"))
    rescue Exception => e
      doc = Nokogiri::HTML(HTTParty.get("http://www.crunchbase.com/people?c=#{q}"))
    end
    doc.css(".col2_table_listing li").each do |li|
      $db["people_names"].save({:href => "http://www.crunchbase.com" + li.css("a")[0].attributes["href"].text, :name => li.css("a")[0].attributes["title"].text}) if li.css("a")[0]
    end
  end
end


def get_companies
  $queries.each do |q|
    puts "crawling #{q}"
    begin
      doc = Nokogiri::HTML(HTTParty.get("http://www.crunchbase.com/companies?c=#{q}"))
    rescue Exception => e
      doc = Nokogiri::HTML(HTTParty.get("http://www.crunchbase.com/companies?c=#{q}"))
    end
    doc.css(".col2_table_listing li").each do |li|
      $db["companies"].save({:href => "http://www.crunchbase.com" + li.css("a")[0].attributes["href"].text, :name => li.css("a")[0].attributes["title"].text}) if li.css("a")[0]
    end
  end
end


def get_financial_orgs
  $queries.each do |q|
    puts "crawling #{q}"
    begin
      doc = Nokogiri::HTML(HTTParty.get("http://www.crunchbase.com/financial-organizations?c=#{q}"))
    rescue Exception => e
      doc = Nokogiri::HTML(HTTParty.get("http://www.crunchbase.com/financial-organizations?c=#{q}"))
    end
    doc.css(".col2_table_listing li").each do |li|
      $db["financial_orgs"].save({:href => "http://www.crunchbase.com" + li.css("a")[0].attributes["href"].text, :name => li.css("a")[0].attributes["title"].text}) if li.css("a")[0]
    end
  end
end

def get_people_content
  while $db["people_names"].count > 0
      sleep(rand(5))
      person = $db["people_names"].find_and_modify({:remove => true})
      puts "person: #{person["name"]}"
      url = "http://api.crunchbase.com/v/1/people/#{person["href"].gsub("http://www.crunchbase.com/person/", "")}.js"
    begin
      person_json = HTTParty.get("http://api.crunchbase.com/v/1/person/#{person["href"].gsub("http://www.crunchbase.com/person/", "")}.js")
      $db["people"].save(person_json)
    rescue Exception => e
      puts "Failed to fetch person: #{person["name"]}"
      $db["failed_people"].save(person)
    end
  end
end

def get_companies_content
  while $db["company_names"].count > 0
    sleep(rand(5))
    company = $db["company_names"].find_and_modify({:remove => true})
    puts "company: #{company["name"]}"
    begin
      company_json = HTTParty.get("http://api.crunchbase.com/v/1/company/#{company["href"].gsub("http://www.crunchbase.com/company/", "")}.js")
      $db["companies"].save(company_json)
    rescue Exception => e
      puts "Failed to fetch company: #{company["name"]}"
      $db["failed_companies"].save(company)
    end
  end
end

def get_financial_orgs_content
  while $db["financial_orgs"].count > 0
    sleep(rand(3))
    org = $db["financial_orgs"].find_and_modify({:remove => true})
    puts "financial org: #{org["name"]}"
    begin
      org_json = HTTParty.get("http://api.crunchbase.com/v/1/financial-organization/#{person["href"].gsub("http://www.crunchbase.com/person/", "")}.js"
      $db["financial"].save(org_json)
    rescue Exception => e
      puts "Failed to fetch org: #{org["name"]}"
      $db["failed_financial"].save(org)
    end
  end
end


#get_companies
#get_people
#get_companies_content
#get_people_content
get_financial_orgs
