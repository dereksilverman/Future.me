class CreateLocations < ActiveRecord::Migration
  def change
    create_table :locations do |t|
      t.string :city
      t.string :state
      t.string :country
      t.decimal :lat
      t.decimal :long

      t.timestamps
    end
  end
end
