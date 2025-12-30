require 'rails_helper'

RSpec.describe Api::V2::MembershipsController, type: :controller do
  let(:membership) { Fabricate(:membership) }
  let(:other_membership) { Fabricate(:membership) }

  before { membership.organization.set(feature_mum: true) }

  describe "GET 'index'" do
    context "signed in" do
      before { sign_in membership.user }

      it "returns a 200" do
        get :index
        expect(response.status).to eq(200)
      end

      it "returns the current user's memberships" do
        get :index
        expect(JSON.parse(response.body)["memberships"].length).to eq(1)
      end
    end

    context "signed out" do
      it "returns a 302" do
        get :index
        expect(response.status).to eq(302)
      end
    end
  end

  describe "GET 'show'" do
    context "signed in" do
      before { sign_in membership.user }
      it "returns a 200" do
        get :show, params: { id: membership.id }
        expect(response.status).to eq(200)
      end

      it "returns the membership" do
        get :show, params: { id: membership.id }
        expect(JSON.parse(response.body)["membership"].present?).to be(true)
      end
    end

    context "signed out" do
      it "returns a 302" do
        get :index
        expect(response.status).to eq(302)
      end
    end
  end

  describe "PUT 'update'" do
    context "signed in" do
      context "good params" do

        before { sign_in membership.organization.owner }
        it "returns a 200" do
          put :update, params: { id: membership.id, membership: { guests_report: true } }
          expect(response.status).to eq(200)
        end

        it "updates the appropriate fields" do
          put :update, params: { id: membership.id, membership: { guests_report: true } }
          expect{membership.reload}.to change { membership.guests_report }.from(false).to(true)
        end
      end

      context "bad params" do
        before { sign_in membership.organization.owner }

        it "returns an error" do
          put :update, params: { id: membership.id, membership: { email: '' } }
          expect(response.status).to eq(422)
          expect(JSON.parse(response.body)["errors"]["email"].present?).to be(true)
        end
      end

      context "you don't own the organization" do
        before { sign_in other_membership.organization.owner }

        it "should return a 403" do
          put :update, params: { id: membership.id, membership: { admin: true } }, as: :json
          expect(response.status).to eq(403)
        end
      end

      context "you are the individual member" do
        before { sign_in membership.user }

        it "should a return 403" do
          put :update, params: { id: membership.id, membership: { admin: true } }, as: :json
          expect(response.status).to eq(403)
        end
      end
    end

    context "signed out" do
      it "returns 401" do
        put :update, params: { id: membership.id, membership: { admin: true } }, as: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe "POST 'create'" do
    let(:good_params) { Fabricate.attributes_for(:membership) }

    context "signed in" do
      context "good params" do
        before { sign_in membership.organization.owner }
        it "returns a 200" do
          post :create, params: { membership: good_params.merge(organization_id: membership.organization.id) }
          expect(response.status).to eq(200)
        end
      end

      context "bad params" do
        before { sign_in membership.organization.owner }

        it "returns a 422" do
          post :create, params: { membership: good_params.merge(organization_id: membership.organization.id, email: '') }
          expect(response.status).to eq(422)
        end

        it "returns an error" do
          post :create, params: { membership: good_params.merge(organization_id: membership.organization.id, email: '') }
          expect(JSON.parse(response.body)["errors"]["email"].present?).to be(true)
        end
      end

      context "you don't own the organization" do
        before { sign_in other_membership.organization.owner }

        it "should return a 403" do
          post :create, params: { membership: good_params.merge(organization_id: membership.organization.id) }, as: :json
          expect(response.status).to eq(403)
        end
      end

      context "email already exists" do
        before { sign_in membership.organization.owner }

        it "returns an error" do
          post :create, params: { membership: good_params.merge(organization_id: membership.organization.id, email: membership.email) }
          expect(response.status).to eq(422)
          expect(JSON.parse(response.body)["errors"]["email"].present?).to be(true)
        end
      end
    end

    context "signed out" do
      it "returns a 302" do
        get :index
        expect(response.status).to eq(302)
      end
    end
  end

  describe "DELETE 'destroy'" do
    context "signed in" do
      context "own membership" do
        before { sign_in membership.organization.owner }
        it "returns a 204" do
          delete :destroy, params: { id: membership.id }
          expect(response.status).to eq(204)
        end
      end

      context "other's membership" do
        before { sign_in membership.user }
        it "returns a 403" do
          delete :destroy, params: { id: membership.id }, as: :json
          expect(response.status).to eq(403)
        end
      end
    end

    context "signed out" do
      it "returns a 302" do
        delete :destroy, params: { id: membership.id }
        expect(response.status).to eq(302)
      end
    end
  end
end
