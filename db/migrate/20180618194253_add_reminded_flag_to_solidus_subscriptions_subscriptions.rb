class AddRemindedFlagToSolidusSubscriptionsSubscriptions < ActiveRecord::Migration[5.1]
  def change
    add_column :solidus_subscriptions_subscriptions, :reminded, :boolean, null: false, default: false
  end
end
