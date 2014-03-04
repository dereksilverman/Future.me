class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :omniauthable, :recoverable, :rememberable, :trackable, :validatable
  # attr_accessible :email, :password, :password_confirmation, :remember_me, :username
  after_save :create_connections

  has_many :user_people
  has_many :people, :through => :user_people

  @@connections = []

  def self.from_omniauth(auth)
    where(auth.slice(:provider, :uid)).first_or_create do |user|
      user.provider = auth.provider
      user.uid = auth.uid
      user.email = auth.info.email
      user.create_people(auth) # creates other people plus user's @@connections
      user.create_person(auth, user) # calls the method to store data and passes params
 	  end
  end



  def new_with_session(params, session)
  	if session["devise.user_attributes"]
  		new(session["devise.user_attributes"], without_protection: true) do |user|
  			user.attributes = params
  			user.valid?
  		end
  	else
  		super
  	end
  end

  def update_with_password(params, *options)
	  if encrypted_password.blank?
	    update_attributes(params, *options)
	  else
	    super
	  end
	end

  # *** THESE METHODS STORE USER'S INFO IN DB ***

  # create person object for the user
  def create_person(auth, user)
     # connections are lots of people objects!
    person = Person.delay.find_or_create_by_firstname_and_lastname_and_linkedin_id_and_linkedin_url(
        auth.info.first_name, auth.info.last_name, user.uid, auth.info.urls["public_profile"]) 
    # Call other two methods and pass person as param
    user_companies(person, auth, user)
    user_schools(person, auth, user)
    add_connection_details(user)
  end

  def create_people(auth)
    @@connections = auth.extra["raw_info"]["connections"]["values"].map do |person_hash|
      if person_hash.siteStandardProfileRequest
        new_person = Person.delay.find_or_create_by_firstname_and_lastname_and_linkedin_id_and_linkedin_url(
          person_hash.firstName, person_hash.lastName, person_hash.id, person_hash.siteStandardProfileRequest.url)
      else
        new_person = Person.delay.find_or_create_by_firstname_and_lastname_and_linkedin_id(
          person_hash.firstName, person_hash.lastName, person_hash.id)
      end
    end
  end

  def create_connections
    if @@connections
      @@connections.each do |person|
        people << person unless people.include? person
      end
    end
    add_connection_details
  end

  def user_companies(person, auth, user)
    if auth.extra["raw_info"].positions["values"] != nil
      positions_array = auth.extra["raw_info"].positions["values"]

      positions_array.each do |position_hash|
        # Create companies
        company = Company.delay.find_or_create_by_name_and_linkedin_id(position_hash.company.name, 
          position_hash.company.id)
        industry = Industry.delay.find_or_create_by_name(position_hash.company.industry)

        # Get company location from the API
        company_location(company)        

      # Format dates because given as separate month and year..WTF!
      if position_hash.startDate
        startYr = position_hash.startDate.year
        startMth = position_hash.startDate.month || 1
        startDate = Date.new(startYr, startMth) 
      end
      if position_hash.endDate # current position has no end date
        endYr = position_hash.endDate.year
        endMth = position_hash.endDate.month || 1
        endDate = Date.new(endYr,endMth)
      end


        # Create jobtitle
        jobtitle = Jobtitle.delay.find_or_create_by_title_and_start_date_and_end_date_and_company_id(position_hash.title, 
          startDate, endDate, company.id)
        
        # Make associations
        person.companies << company
        company.industries << industry
        person.jobtitles << jobtitle

        # Save the ones that had associations
        person.save
        company.save
      end
    end
  end

  def company_location(company)
    api = Api.new
    api.company_id = company.linkedin_id  
    api.company_details
    api.company_postalcode
    location = Location.delay.find_or_create_by_postalcode(api.company_postalcode)
    company.locations << location
  end

  def user_schools(person, auth, user)
    edu_array = auth.extra["raw_info"].educations.values[1]
    edu_array.each do |edu_hash|
      # Create school
      school = School.delay.find_or_create_by_name(edu_hash.schoolName)
      person.schools << school
      
      # Create education
      grad_yr = edu_hash.endDate.year if edu_hash.endDate
      
      education = Education.delay.find_or_create_by_kind_and_major_and_grad_yr_and_school_id(
          edu_hash.degree, edu_hash.fieldOfStudy, grad_yr, school.id)
      person.educations << education  
      person.save    
    end 
  end

  # this is where things slowwwww dowwwwwwwwnnnn
  # somewhere in here the absolute URL needed (not nil) is called
  def add_connection_details
    @@connections.each do |person|
      # this takes a long time
      public_profile_url = Api.new.delay.get_public_profile_url(person.linkedin_id) # need this bc oauth gives a diff url
      @scrape = Scraper.new(public_profile_url)
      if @scrape.profile
        @scrape.educations.each do |school|
          this_school = School.delay.find_or_create_by_name(school[:name])
          person.schools << this_school
          # regex out the kind and major
          match = (/([^,]*),? ?(.*)/).match(school[:description])
          if match
            education = Education.delay.find_or_create_by_kind_and_major_and_grad_yr_and_school_id(
              match[1], match[2], school[:period], this_school.id)
          else
            education = Education.delay.find_or_create_by_kind_and_grad_yr_and_school_id(
              school[:description], school[:period], this_school.id)
          end
          person.educations << education unless person.educations.include? education
          # Save this after shoveling
          person.save
        end

        @scrape.current_companies.each do |company|
          this_company = Company.delay.find_or_create_by_name_and_url_and_address(
            company[:company], company[:website], company[:address])
          person.companies << this_company unless person.companies.include? this_company

          if this_company.address
            matchdata = this_company.address.match(/\d{5}/)
            if matchdata
              this_location = Location.delay.find_or_create_by_postalcode(matchdata[0].to_i)
              # self.city_state_lon_lat
              this_company.locations << this_location unless this_company.locations.include? this_location

              this_company.save
            end
          end

          this_industry = Industry.delay.find_or_create_by_name(company[:industry])
          if this_company.industries
            this_company.industries << this_industry unless this_company.industries.include? this_industry
            # this_company.save
          end

          jobtitle = Jobtitle.delay.find_or_create_by_title_and_start_date_and_end_date_and_company_id(
            company[:title], company[:start_date], company[:end_date], this_company.id)
          person.jobtitles << jobtitle unless person.jobtitles.include? jobtitle
          # Save this after shoveling
          # person.save
        end

        @scrape.past_companies.each do |company|
          # this_company = Companydelay.find_or_create_by_name_and_url_and_address(
          #   company[:company], company[:website], company[:address])
          this_company = Company.delay.find_or_create_by_name(
            company[:company])
          if this_company.url.nil?
            this_company.update_attributes(:url=>company[:website],:address=>company[:address])
          end
          person.companies << this_company unless person.companies.include? this_company

          if this_company.address
            matchdata = this_company.address.match(/\d{5}/)

            if matchdata 
              this_location = Location.delay.find_or_create_by_postalcode(matchdata[0].to_i)
              # self.city_state_lon_lat
              this_company.locations << this_location unless this_company.locations.include? this_location

              # this_company.save
              this_company.save
            end
          end

          this_industry = Industry.delay.find_or_create_by_name(company[:industry])
          if this_company.industries
            this_company.industries << this_industry unless this_company.industries.include? this_industry
            # this_company.save
          end

          jobtitle = Jobtitle.delay.find_or_create_by_title_and_start_date_and_end_date_and_company_id(
            company[:title], company[:start_date], company[:end_date], this_company.id)
          person.jobtitles << jobtitle unless person.jobtitles.include? jobtitle
          # Save this after shoveling
          # person.save
        end
      end
    end
  end

  def self.city_state_lon_lat
    # locations = Location.all
    # locations.each do |location|
      postalcode = this_location.postalcode.to_s 
      if postalcode.length == 5 
        this_location.update_attributes(:city => postalcode.to_region(:city => true),
          :state => postalcode.to_region(:state => true), 
          :long => postalcode.to_lon, 
          :lat => postalcode.to_lat)
      end
    # end
  end

  
end

# MISSING INFO TO GET FROM SCRAPER:
# - company url and address
