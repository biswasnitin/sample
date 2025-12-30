class MembershipsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_membership, only: [:show, :destroy, :update]
  before_action :set_organization, only: [:create]

  def index
    @memberships = Membership.where(user_id: current_user.id)
    render json: @memberships, each_serializer: MembershipSerializer
  end

  def show
    authorize! :read, @membership

    render json: @membership, serializer: MembershipSerializer
  end

  def update
    @membership.assign_attributes(edit_params)

    # Check after assignment in case the request has inappropriately assigned listing_id
    authorize! :manage, @membership

    if @membership.save
      render json: @membership, serializer: MembershipSerializer
    else
      render json: { errors: @membership.errors }, status: :unprocessable_entity
    end
  end

  def create
    @membership = @organization.memberships.new(create_params)
    authorize! :create, @membership

    if @membership.save
      render json: @membership, serializer: MembershipSerializer
    else
      render json: { errors: @membership.errors }, status: 422
    end
  end

  def destroy
    authorize! :delete, @membership

    if @membership.delete
      render json: {}, status: 204
    else
      render json: { errors: @membership.errors }, status: 422
    end
  end

private

  def set_membership
    @membership = Membership.find(params[:id])
  end

  def set_organization
    @organization = Organization.find(create_params[:organization_id])
  end

  def create_params
    params.require(:membership).permit(*(
      [:email, :all_listings, :role_name, :organization_id, listing_ids: []] + Membership.permission_fields
    ))
  end

  def edit_params
    params.require(:membership).permit(*(
      [:email, :all_listings, :role_name, :organization_id, listing_ids: []] + Membership.permission_fields
    ))
  end
end
