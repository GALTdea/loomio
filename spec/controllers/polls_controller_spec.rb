
require 'rails_helper'

describe PollsController do
  let(:group) { create :group, is_visible_to_public: true }
  let(:discussion) { create :discussion, private: false, group: group }
  let(:poll) { create :poll, author: user }
  let(:user) { create :user }
  let(:identity) { create :facebook_identity, user: user }
  let(:community) { create :facebook_community, identity: identity, poll_id: poll.id, identifier: "fb_one" }
  let(:another_community) { create :facebook_community, identifier: "fb_two" }
  let(:another_poll) { create :poll }
  let(:closed_poll) { create :poll, author: user, closed_at: 1.day.ago }

  describe 'index' do
    before { poll; another_poll; closed_poll }

    it 'shows polls I have started' do
      sign_in user
      get :index

      json = JSON.parse(response.body)
      poll_ids = json['polls'].map { |p| p['id'] }
      expect(poll_ids).to include poll.id
      expect(poll_ids).to include closed_poll.id
      expect(poll_ids).to_not include another_poll.id
    end

    it 'filters by active' do
      sign_in user
      get :index, authored_only: true, filter: :active

      json = JSON.parse(response.body)
      poll_ids = json['polls'].map { |p| p['id'] }
      expect(poll_ids).to include poll.id
      expect(poll_ids).to_not include closed_poll.id
      expect(poll_ids).to_not include another_poll.id
    end

    it 'filters by closed' do
      sign_in user
      get :index, authored_only: true, filter: :closed

      json = JSON.parse(response.body)
      poll_ids = json['polls'].map { |p| p['id'] }
      expect(poll_ids).to_not include poll.id
      expect(poll_ids).to include closed_poll.id
      expect(poll_ids).to_not include another_poll.id
    end

    it 'does not display polls for logged out users' do
      get :index, authored_only: true

      json = JSON.parse(response.body)
      expect(json).to be_empty
    end
  end

  describe 'show' do
    it 'sets metadata for public polls' do
      poll.update(anyone_can_participate: true)
      get :show, key: poll.key
      expect(assigns(:metadata)[:title]).to eq poll.title
    end

    it 'does not set metadata for private polls' do
      get :show, key: poll.key
      expect(assigns(:metadata)[:title]).to be_nil
    end

    it 'can show metadata for a community link' do
      get :show, key: poll.key, identifier: community.identifier
      expect(assigns(:metadata)[:title]).to eq poll.title
    end

    it 'does not show identifiers for other communities' do
      get :show, key: poll.key, identifier: another_community.identifier
      expect(assigns(:metadata)[:title]).to be_nil
    end
  end

  describe 'share' do
    it 'allows the author to share a poll' do
      sign_in user
      get :share, key: poll.key
      expect(response.status).to eq 200
    end

    it 'allows a group admin to share a poll' do
      poll.update(discussion: discussion)
      sign_in poll.group.admins.first
      get :share, key: poll.key
      expect(response.status).to eq 200
    end

    it 'does not allow other users to share the poll' do
      sign_in create(:user)
      get :share, key: poll.key
      expect(response.status).to eq 302
    end

    it 'does not allow visitors to share the poll' do
      get :share, key: poll.key
      expect(response.status).to eq 302
    end
  end
end
