class Api
  attr_accessor :company_id, :company_name, :company_industry, :company_postalcode, 
  :firstname, :lastname, :linkedin_id, :linkedin_url, :people, :person_params

  CONSUMER_ADMIN = OAuth::Consumer.new(ENV["LINKEDIN_KEY"], ENV["LINKEDIN_SECRET"])
  ACCESS_TOKEN = OAuth::AccessToken.new(CONSUMER_ADMIN, ENV["LI_OAUTH_KEY"],ENV["LI_OAUTH_SECRET"])

  def run(email)
    find_company(email)
    company_details
    company_employees
  end

  def find_company(email)
    json_txt = ACCESS_TOKEN.get("https://api.linkedin.com/v1/companies?email-domain=#{email}", 'x-li-format' => 'json').body
    parsed = JSON.parse(json_txt)["values"][0]
    @company_id = parsed["id"]
    @company_name = parsed["name"]
  end

  def company_details
    json_txt = ACCESS_TOKEN.get("http://api.linkedin.com/v1/companies/#{@company_id}:(name,industries,company-type,locations,employee-count-range)", 'x-li-format' => 'json').body
    parsed = JSON.parse(json_txt)
    if parsed["industries"]
      @company_industry = parsed["industries"]["values"][0]["name"]
    end
    if parsed["locations"]
      @company_postalcode = parsed["locations"]["values"][0]["address"]["postalCode"]
    end
  end

  def company_employees
    int = 0
    company_gsub = @company_name.gsub(" ","%20")
    json_txt = ACCESS_TOKEN.get("https://api.linkedin.com/v1/people-search:(people:(first-name,last-name,id,public-profile-url))?company-name=#{company_gsub}&current-company=true&sort=connections&count=25&start=0", 'x-li-format' => 'json').body
    parsed = JSON.parse(json_txt)
    # set limit so that we don't call more than 10,000 or something
    until parsed["people"]["_total"] < int #if there are less than 25 on one page then we're missing those few.. UPDATE METHOD
      json_txt = ACCESS_TOKEN.get("https://api.linkedin.com/v1/people-search:(people:(first-name,last-name,id,public-profile-url))?company-name=#{company_gsub}&current-company=true&sort=connections&count=25&start=#{int}", 'x-li-format' => 'json').body
      parsed = JSON.parse(json_txt)
      if @people.nil?
        @people = JSON.parse(json_txt)["people"]["values"]
      else
        JSON.parse(json_txt)["people"]["values"].each do |person|
          @people << person
        end
      end
      int += 25
    end
    @people.uniq!
  end

  def get_public_profile_url(linkedin_id)
    json_txt = ACCESS_TOKEN.get("https://api.linkedin.com/v1/people/id=#{linkedin_id}:(public-profile-url)", 'x-li-format' => 'json').body
    parsed = JSON.parse(json_txt)
    return parsed["publicProfileUrl"]
  end



    # NOT BEING USED
  # generalize this thing i keep doing over and over. method would take two arguments: url and hash of k-v pairs
  # def get_admin
  #   json_txt = ACCESS_TOKEN.get("http://api.linkedin.com/v1/people/~:(#{FIELDS})", 'x-li-format' => 'json').body
  #   parsed = JSON.parse(json_txt)
  #   create_person(parsed)
  #   # returns all FIELDS
  # end

  # NOT BEING USED
  # def get_person(id)
  #   json_txt = ACCESS_TOKEN.get("http://api.linkedin.com/v1/people::(id=#{id}):(#{FIELDS})", 'x-li-format' => 'json').body
  #   parsed = JSON.parse(json_txt)
  #   create_person(parsed)
  #   # returns some FIELDS
  # end

  # NOT BEING USED
  # def create_person(parsed)
  #   firstname = parsed["firstName"]
  #   lastname = parsed["lastName"]
  #   linkedin_id = parsed["id"]
  #   Person.create(:firstname => firstname, :lastname => lastname, :linkedin_id => linkedin_id)
  # end
end 
