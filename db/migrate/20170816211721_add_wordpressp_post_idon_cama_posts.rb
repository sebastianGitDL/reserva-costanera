class AddWordpresspPostIdonCamaPosts < ActiveRecord::Migration[5.0]
  def change
    add_column :cama_posts, :wp_post_id, :integer
  end
end
