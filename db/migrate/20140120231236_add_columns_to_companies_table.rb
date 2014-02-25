class AddColumnsToCompaniesTable < ActiveRecord::Migration
  def change
    add_column :companies, :linkedin_url, :string
  end
end
