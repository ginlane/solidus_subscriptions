# frozen_string_literal: true

module Spree
  class SubscriptionMailer < BaseMailer
    def reminder_email(subscription, resend = false)
      @subscription = subscription
      @store = @subscription.store
      subject = build_subject('Subscription Reminder', resend)

      mail(to: @subscription.user.email, from: from_address(@store), subject: subject)
    end

    private

    def build_subject(subject_text, resend)
      resend_text = (resend ? "[#{t('spree.resend').upcase}] " : '')
      "#{resend_text}#{@subscription.store.name} #{subject_text}"
    end
  end
end
