class Industry < ActiveRecord::Base
  attr_accessible :name
  # validates :name, presence: true
  # validates :name, uniqueness: true

  has_many :company_industries
  has_many :companies, :through => :company_industries

  def value
  	self.companies.uniq.size
  end

  def source
    "industries/#{self.id}/companies"
  end
 
end

