require "test_helper"

feature 'users' do
  describe 'as an anonymous visitor' do
    describe 'signing up for an account' do
      scenario 'succeeds with a valid username, password, and email' do
        skip
        # requires verification by an administrator to complete
      end
      scenario 'fails with an existing username or email' do
        skip
      end
      scenario 'fails with an invalid username, email, or password' do
        skip
        # only .edu accounts are allowed
      end
    end

    scenario 'browsing users' do
      skip 'do users have public profile pages? what are they used for?'
    end
  end
  describe 'as a registered user' do
    describe 'logging in' do
      scenario 'succeeds with a valid email and password' do
        skip
      end
      scenario 'fails with a non-existent email or invalid password' do
        skip
      end
      scenario 'sending a password reset email' do
        skip
      end
    end
    describe 'updating account' do
      scenario 'changing email address' do
        skip
      end
      scenario 'changing password' do
        skip
      end
      scenario 'changing profile information' do
        skip
      end
    end
  end
  describe 'as an administrator' do
    scenario 'verifying a new user account' do
      skip
    end
    scenario 'rejecting a new user account' do
      skip
    end
  end
end
