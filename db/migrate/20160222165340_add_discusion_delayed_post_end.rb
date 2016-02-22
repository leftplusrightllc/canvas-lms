class AddDiscusionDelayedPostEnd < ActiveRecord::Migration
	tag :predeploy
  def up
  	add_column :discussion_topics, :delayed_post_end, :datetime
  end

  def down
  	remove_column :discussion_topics, :delayed_post_end
  end
end
