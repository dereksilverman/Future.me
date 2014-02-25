class AddColumnsPersonModel < ActiveRecord::Migration
  def change
    add_column :people, :linkedin_url, :string
    change_column :companies, :linkedin_id, :string
  end
end
