class DropCompaniesCreateCompanies < ActiveRecord::Migration
  def change
    create_table :companies do |t|
      t.string   :name
      t.integer  :linkedin_id
      t.string   :url
      t.string   :address
      t.string   :display
      t.timestamps
    end
  end
end
