require "test_helper"

feature 'users' do
  describe 'as an anonymous visitor' do
    describe 'signing up for an account' do
      scenario 'succeeds with a valid username, password, and email' do
        # requires verification by an administrator to complete
      end
      scenario 'fails with an existing username or email' do

      end
      scenario 'fails with an invalid username, email, or password' do
        # only .edu accounts are allowed
      end
    end

    scenario 'browsing users' do
        # do users have public profile pages? what are they used for?
    end
  end
  describe 'as a registered user' do
    describe 'logging in' do
      scenario 'succeeds with a valid email and password' do

      end
      scenario 'fails with a non-existent email or invalid password' do

      end
      scenario 'sending a password reset email' do

      end
    end
    describe 'updating account' do
      scenario 'changing email address' do

      end
      scenario 'changing password' do

      end
      scenario 'changing profile information' do

      end
    end
  end
  describe 'as an administrator' do
    scenario 'verifying a new user account' do

    end
    scenario 'rejecting a new user account' do

    end
  end
end
