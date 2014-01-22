class Populate
  attr_reader :api, :scraper, :company, :location, :person, :industry, :scrape

  DOMAINS = ["google.com", "twitter.com", "flatironschool.com"]
  # DOMAINS = ["google.com", "twitter.com", "flatironschool.com", "amazon.com",
  # "facebook.com", "linkedin.com", "squareup.com", "apple.com", "squarespace.com",
  # "tumblr.com", "etsy.com", "yahoo.com", "salesforce.com", "dropbox.com"]

  # WHILE TESTING, COMMENT OUT THE METHODS U DONT WANT TO RUN
  def initialize
    @api = Api.new
    create_company
    create_industry
    create_location
    create_people
    update_people
  end

  def create_company
    # FOR WHEN WE'RE READY TO POPULATE THE WHOLE DB WITH ALL THE COMPANIES...
    # MAYBE THIS WILL BE OUR INITIALIZE METHOD? OR INITIALIZE WILL CALL THIS METHOD?
    # DOMAINS.each do |domain|
    #   @api.find_company(domain)
        # @company = Company.create(:name => @api.company_name, :linkedin_id => @api.company_id)
        # create_industry
        # create_location
        # create_people
        # update_people
    # end
    @api.find_company(DOMAINS.last)
    @company = Company.create(:name => @api.company_name, :linkedin_id => @api.company_id, :linkedin_url => "http://www.linkedin.com/company/#{@api.company_id}")
  end

  def create_industry    
    # WE STILL NEED TO DO THIS FOR CURRENT / PAST COMPANIES
    @industry = Industry.create(:name => @api.company_industry)
    @industry.companies << @company
    @industry.save
  end

  def create_location
    # WE STILL NEED TO DO THIS FOR CURRENT / PAST COMPANIES
    @location = Location.create(:postalcode => @api.company_postalcode)
    @company.locations << @location
    @company.save
  end

  def create_people
    @api.people.each do |personhash|
      Person.create(eval(@api.person_params))
    end
  end

  def update_people
    Person.all.each do |person|
      @scrape = Scraper.new(person.linkedin_url)
      unless @scrape.profile.nil? 
        create_schools_and_educations(@scrape, person)
        create_current_companies(@scrape, person)
        create_past_companies(@scrape, person)
      end
    end
  end

  # THE IDEA HERE IS TO SEPARATE UPDATE_PEOPLE INTO SPECIFIC METHODS BUT THERE'S A SCOPE PROBLEM BC LOCAL VARIABLES DON'T CARRY OVER
  # ALSO WE ONLY WANT TO CREATE 1 INSTANCE OF SCRAPER PER PERSON, THAT'S WHY ALL THE METHODS ARE

  def create_schools_and_educations(scrape, person)
    @scrape.educations.each do |school|
      this_school = School.create(eval(@scrape.school_params))
      person.schools << this_school
      education = Education.create(eval(@scrape.education_params)) # eval is a method that removes quotes from a string, so in this case it turns it into a hash
      person.educations << education
      # Save this after shoveling
      person.save
    end
  end

  def create_current_companies(scrape, person)
    @scrape.current_companies.each do |company|
      this_company = Company.create(eval(@scrape.company_params))
      person.companies << this_company

      unless this_company.address.nil?
        matchdata = this_company.address.match(/\d{5}/)
        if matchdata[0]
          postalcode = matchdata[0]
          this_location = Location.create(:postalcode => postalcode)
        end
        this_company.locations << this_location
        this_company.save
      end

      this_industry = Industry.create(eval(@scrape.company_industry))
      unless this_company.industries.nil?
        this_company.industries << this_industry
        this_company.save
      end

      jobtitle = Jobtitle.create(eval(@scrape.jobtitle_params))
      person.jobtitles << jobtitle
      # Save this after shoveling
      person.save
    end
  end

  def create_past_companies(scrape, person)
    @scrape.past_companies.each do |company|
      this_company = Company.create(eval(@scrape.company_params))
      person.companies << this_company

      unless this_company.address.nil?
        matchdata = this_company.address.match(/\d{5}/)
        if matchdata
          postalcode = matchdata[0]
          this_location = Location.create(:postalcode => postalcode)
        end
        this_location = Location.create(:postalcode => postalcode)
        this_company.locations << this_location
        this_company.save
      end

      this_industry = Industry.create(eval(@scrape.company_industry))
      this_company.industries << this_industry
      this_company.save

      jobtitle = Jobtitle.create(eval(@scrape.jobtitle_params))
      person.jobtitles << jobtitle
      # Save this after shoveling
      person.save
    
    end 
  end

end

