# This job is responsible for sending reminders for upcoming subscription
# fulfillments

module SolidusSubscriptions
  class SubscriptionReminderJob < ActiveJob::Base
     queue_as Config.processing_queue

     # Process a collection of subscriptions
     #
     # @param subscription_ids [Array<Integer>] The ids of the
     #   subscriptions to be processed together and reminded by the same email
     #
     # @return [SolidusSubscriptions::Subscription] The subscriptions that were sent reminders
     def perform(subscription_ids)
       return if subscription_ids.empty?

       subscriptions = SolidusSubscriptions::Subscription.where(id: subscription_ids)
       subscriptions.each do |subscription|
         subscription.remind!
       end

       subscriptions
     end
  end
end
