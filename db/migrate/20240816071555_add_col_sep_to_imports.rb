class AddColSepToImports < ActiveRecord::Migration[7.2]
  def change
    add_column :imports, :col_sep, :string
  end
end
