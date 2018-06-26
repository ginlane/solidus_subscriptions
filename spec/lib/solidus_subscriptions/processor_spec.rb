require 'rails_helper'

RSpec.describe SolidusSubscriptions::Processor, :checkout do
  include ActiveJob::TestHelper
  around { |e| perform_enqueued_jobs { e.run } }

  let!(:user) do
    create(:user, :subscription_user).tap do |user|
      cc = create(:credit_card, gateway_customer_profile_id: 'BGS-123', user: user)
      wallet_cc = user.wallet.add(cc)
      user.wallet.default_wallet_payment_source = wallet_cc
    end
  end

  let!(:remindable_user) do
    create(:user, :subscription_user).tap do |user|
      cc = create(:credit_card, gateway_customer_profile_id: 'BGS-123', user: user)
      wallet_cc = user.wallet.add(cc)
      user.wallet.default_wallet_payment_source = wallet_cc
      create_list(:subscription, 2, :not_actionable, user: user)
    end
  end

  let!(:actionable_subscriptions) { create_list(:subscription, 2, :actionable, user: user, reminded: true) }
  let!(:pending_cancellation_subscriptions) do
    create_list(:subscription, 2, :pending_cancellation, user: user)
  end

  let!(:expiring_subscriptions) do
    create_list(
      :subscription,
      2,
      :actionable,
      :with_line_item,
      user: user,
      line_item_traits: [{ end_date: Date.current.tomorrow }]
    )
  end

  let!(:future_subscriptions) { create_list(:subscription, 2, :not_actionable, user: user) }

  let!(:canceled_subscriptions) { create_list(:subscription, 2, :canceled, user: user) }
  let!(:inactive) { create_list(:subscription, 2, :inactive, user: user) }

  let!(:successful_installments) { create_list :installment, 2, :success }
  let!(:failed_installments) do
    create_list(
      :installment,
      2,
      :failed,
      subscription_traits: [{ user: user }]
    )
  end

  # all subscriptions and previously failed installments belong to the same user
  let(:expected_orders) { 1 }

  shared_examples 'a subscription order' do
    let(:order_variant_ids) { Spree::Order.last.variant_ids }
    let(:expected_ids) do
      subs = actionable_subscriptions + pending_cancellation_subscriptions + expiring_subscriptions
      subs_ids = subs.flat_map { |s| s.line_items.pluck(:subscribable_id) }
      inst_ids = failed_installments.flat_map { |i| i.subscription.line_items.pluck(:subscribable_id) }

      subs_ids + inst_ids
    end

    it 'creates the correct number of orders' do
      expect { subject }.to change { Spree::Order.complete.count }.by expected_orders
    end

    it 'creates the correct order' do
      subject
      expect(order_variant_ids).to match_array expected_ids
    end

    it 'advances the subsription actionable dates' do
      subscription = actionable_subscriptions.first

      current_date = subscription.actionable_date
      expected_date = subscription.next_actionable_date

      expect { subject }.
        to change { subscription.reload.actionable_date }.
        from(current_date).to(expected_date)
    end

    it 'cancels subscriptions pending cancellation' do
      subs = pending_cancellation_subscriptions.first
      expect { subject }.
        to change { subs.reload.state }.
        from('pending_cancellation').to('canceled')
    end

    it 'resets the subscription successive skip count' do
      subs = pending_cancellation_subscriptions.first
      expect { subject }.
        to change { subs.reload.state }.
        from('pending_cancellation').to('canceled')
    end

    it 'deactivates expired subscriptions' do
      sub = expiring_subscriptions.first

      expect { subject }.
        to change { sub.reload.state }.
        from('active').to('inactive')
    end

    it 'marks future subscriptions as reminded' do
      reminded = future_subscriptions.first
      expect { subject }.
        to change { reminded.reload.reminded }.
        from(false).to(true)
    end

    it 'prepares actionable subscriptions to be reminded in the future' do
      actionable = actionable_subscriptions.first
      expect { subject }.
        to change { actionable.reload.reminded }.
        from(true).to(false)
    end

    it 'reminds users with only remindable subscriptions' do
      remindable = remindable_user.subscriptions.first
      expect { subject }.
        to change { remindable.reload.reminded }.
        from(false).to(true)
    end

    context 'the subscriptions have different shipping addresses' do
      let!(:sub_to_different_address) do
        create(:subscription, :actionable, :with_address, user: user)
      end

      it 'creates an order for each shipping address' do
        expect { subject }.to change { Spree::Order.complete.count }.by 2
      end
    end
  end

  describe '.run' do
    subject { described_class.run }
    it_behaves_like 'a subscription order'
  end

  describe '#build_jobs' do
    subject { described_class.new([user, remindable_user]).build_jobs }
    it_behaves_like 'a subscription order'
  end
end
