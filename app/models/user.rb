class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :omniauthable, :recoverable, :rememberable, :trackable, :validatable
  # attr_accessible :email, :password, :password_confirmation, :remember_me, :username
  after_save :create_connections

  has_many :user_people
  has_many :people, :through => :user_people

  def self.from_omniauth(auth)
    where(auth.slice(:provider, :uid)).first_or_create do |user|
      user.provider = auth.provider
      user.uid = auth.uid
      user.email = auth.info.email

      self.create_people(auth) # creates other people plus user's @connections

      self.create_person(auth, user) # calls the method to store data and passes params
 	  end
  end

  def self.new_with_session(params, session)
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

  def self.create_person(auth, user)
    person = Person.find_or_create_by_firstname_and_lastname_and_linkedin_id_and_linkedin_url(
        auth.info.first_name, auth.info.last_name, user.uid, auth.info.urls["public_profile"]) 
    # Call other two methods and pass person as param
    self.user_companies(person, auth, user)
    self.user_schools(person, auth, user)
  end

  def self.create_people(auth)
    @@connections = auth.extra["raw_info"]["connections"]["values"].map do |person_hash|
      if person_hash.siteStandardProfileRequest
        new_person = Person.find_or_create_by_firstname_and_lastname_and_linkedin_id_and_linkedin_url(
          person_hash.firstName, person_hash.lastName, person_hash.id, person_hash.siteStandardProfileRequest.url)
      else
        new_person = Person.find_or_create_by_firstname_and_lastname_and_linkedin_id(
          person_hash.firstName, person_hash.lastName, person_hash.id)
      end
    end
  end

  def create_connections
    @@connections.each do |person|
      self.people << person unless self.people.include? person
    end
  end

  def self.user_companies(person, auth, user)
    positions_array = auth.extra["raw_info"].positions["values"]
  
    positions_array.each do |position_hash|
      # Create companies
      company = Company.find_or_create_by_name_and_linkedin_id(position_hash.company.name, 
        position_hash.company.id)
      industry = Industry.find_or_create_by_name(position_hash.company.industry)

      # Get company location from the API
      self.company_location(company)
      
      # Format dates because given as separate month and year..WTF!
      startDate = Date.new(position_hash.startDate.year,position_hash.startDate.month)
      if position_hash.endDate # current position has no end date
        endDate = Date.new(position_hash.endDate.year,position_hash.endDate.month) 
      end

      # Create jobtitle
      jobtitle = Jobtitle.find_or_create_by_title_and_start_date_and_end_date_and_company_id(position_hash.title, 
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

  def self.company_location(company)
    api = Api.new
    api.company_id = company.linkedin_id  
    api.company_details
    api.company_postalcode
    location = Location.find_or_create_by_postalcode(api.company_postalcode)
    company.locations << location
  end

  def self.user_schools(person, auth, user)
    edu_array = auth.extra["raw_info"].educations.values[1]
    edu_array.each do |edu_hash|
      # Create school
      school = School.find_or_create_by_name(edu_hash.schoolName)
      person.schools << school
      
      # Create education
      grad_yr = edu_hash.endDate.year if edu_hash.endDate
      
      education = Education.find_or_create_by_kind_and_major_and_grad_yr_and_school_id(
          edu_hash.degree, edu_hash.fieldOfStudy, grad_yr, school.id)
      person.educations << education  
      person.save    
    end 
  end
  

end

# MISSING INFO TO GET FROM SCRAPER:
# - company url and address
