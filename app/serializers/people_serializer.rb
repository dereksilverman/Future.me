class PeopleSerializer < ActiveModel::Serializer
  attributes :id, :firstname, :lastname, :linkedin_url, :value

end
