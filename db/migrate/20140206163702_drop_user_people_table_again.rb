class DropUserPeopleTableAgain < ActiveRecord::Migration
  def change
    drop_table :user_people
  end
end
