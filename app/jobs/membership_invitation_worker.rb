class MembershipInvitationWorker
  include Sidekiq::Worker
  sidekiq_options queue: :emails, retry: false

  def perform(membership_id)
    begin
      membership = Membership.find(membership_id)
      sift_interactor = SiftInteractor.new(current_user: membership.organization.owner)
      membership.send_invite if sift_interactor.create_invite(membership: membership)
    rescue *[Emailer::EmailingUnconfirmedRecipientBuyer, Emailer::EmailingBlacklistedEmail, Mongoid::Errors::DocumentNotFound] => ex
      Sidekiq.logger.warn "#{ex}"
    end
  end
end
