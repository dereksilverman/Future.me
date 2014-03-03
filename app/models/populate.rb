class Populate
  attr_reader :api, :scraper, :company, :location, :person, :industry, :scrape

  DOMAINS = ["flatironschool.com"]

  REPEAT_COMPANY_NAMES = {"google" => "Google", "twitter" => "Twitter"}
  # "google.com", "twitter.com", "flatironschool.com" "tumblr.com", "etsy.com", "yahoo.com", "salesforce.com", "dropbox.com", "apple.com", "squarespace.com"

  def initialize
    @api = Api.new
    create_company
    create_industry
    create_location
    create_people
    update_people
  end

  def create_industry    
    @industry = Industry.find_or_create_by_name(@api.company_industry)
    @industry.companies << @company unless @industry.companies.include? @company
    # @industry.save
  end

  def create_location
    @location = Location.find_or_create_by_postalcode(@api.company_postalcode)
    @company.locations << @location 
    city_state_lon_lat
    @company.locations << @location unless @company.locations.include? @location
    @company.save
  end

  def create_people
    @api.people.each do |personhash|
      Person.find_or_create_by_firstname_and_lastname_and_linkedin_id_and_linkedin_url(
        personhash['firstName'], personhash['lastName'], personhash['id'], personhash['publicProfileUrl'])
    end
  end

  def update_people
    Person.all.each do |person|
      @scrape = Scraper.new(person.linkedin_url)
      if @scrape.profile
        create_schools_and_educations(@scrape, person)
        create_current_companies(@scrape, person)
        create_past_companies(@scrape, person)
      end
    end
  end

  def create_schools_and_educations(scrape, person)
    @scrape.educations.each do |school|
      this_school = School.find_or_create_by_name(school[:name])
      person.schools << this_school
      # regex out the kind and major
      match = (/([^,]*),? ?(.*)/).match(school[:description])
      if match
        education = Education.find_or_create_by_kind_and_major_and_grad_yr_and_school_id(
          match[1], match[2], school[:period], this_school.id)
      else
        education = Education.find_or_create_by_kind_and_grad_yr_and_school_id(
          school[:description], school[:period], this_school.id)
      end
      person.educations << education unless person.educations.include? education
      # Save this after shoveling
      # person.save
    end
  end

  def create_current_companies(scrape, person)
    @scrape.current_companies.each do |company|
      this_company = Company.find_or_create_by_name_and_url_and_address(
        company[:company], company[:website], company[:address])
      person.companies << this_company unless person.companies.include? this_company

      if this_company.address
        matchdata = this_company.address.match(/\d{5}/)
        if matchdata
          @location = Location.find_or_create_by_postalcode(matchdata[0].to_i)
          city_state_lon_lat
          this_company.locations << @location unless this_company.locations.include? this_location
          this_company.save
        end
      end

      this_industry = Industry.find_or_create_by_name(company[:industry])
      if this_company.industries
        this_company.industries << this_industry unless this_company.industries.include? this_industry
        # this_company.save
      end

      jobtitle = Jobtitle.find_or_create_by_title_and_start_date_and_end_date_and_company_id(
        company[:title], company[:start_date], company[:end_date], this_company.id)
      person.jobtitles << jobtitle unless person.jobtitles.include? jobtitle
      # Save this after shoveling
      # person.save
    end
  end

  def create_past_companies(scrape, person)
    @scrape.past_companies.each do |company|
      # this_company = Company.find_or_create_by_name_and_url_and_address(
      #   company[:company], company[:website], company[:address])
      this_company = Company.find_or_create_by_name(
        company[:company])
      if this_company.url.nil?
        this_company.update_attributes(:url=>company[:website],:address=>company[:address])
      end
      person.companies << this_company unless person.companies.include? this_company

      if this_company.address
        matchdata = this_company.address.match(/\d{5}/)
        if matchdata
          this_location = Location.find_or_create_by_postalcode(matchdata[0].to_i)
          this_company.locations << this_location 
          @location = Location.find_or_create_by_postalcode(matchdata[0].to_i)
          city_state_lon_lat
          this_company.locations << @location unless this_company.locations.include? this_location
          # this_company.save
          this_company.save
        end
      end

      this_industry = Industry.find_or_create_by_name(company[:industry])
      if this_company.industries
        this_company.industries << this_industry unless this_company.industries.include? this_industry
        # this_company.save
      end

      jobtitle = Jobtitle.find_or_create_by_title_and_start_date_and_end_date_and_company_id(
        company[:title], company[:start_date], company[:end_date], this_company.id)
      person.jobtitles << jobtitle unless person.jobtitles.include? jobtitle
      # Save this after shoveling
      # person.save
    end
  end

  def city_state_lon_lat
    # locations = Location.all
    # locations.each do |location|
      postalcode = @location.postalcode.to_s 
      if postalcode.length == 5 
        @location.update_attributes(:city => postalcode.to_region(:city => true),
          :state => postalcode.to_region(:state => true), 
          :long => postalcode.to_lon, 
          :lat => postalcode.to_lat)
      end
    # end
  end

  def display_names
    @company.name.split(" ").each do |name|
      if REPEAT_COMPANY_NAMES[name]
        @company.update_attribute(:display => "#{REPEAT_COMPANY_NAMES[name]}")
      end
    end
  end
end




