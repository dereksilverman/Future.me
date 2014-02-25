class CreateUserPeopleTable < ActiveRecord::Migration
  def change
    create_table :user_people do |t|
      t.integer :user_id
      t.integer :person_id
      t.timestamps
    end
  end
end
