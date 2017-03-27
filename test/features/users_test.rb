require 'test_helper'

feature 'users' do
  describe 'as an anonymous visitor' do
    describe 'signing up for an account' do
      before do
        visit '/'
        click_link 'sign in'
        # click_link 'SIGN UP NOW' # This link is only in the JS popup
        click_link "If you don't have a login"
      end

      scenario 'succeeds with a valid username, password, and email' do
        fill_in 'Login', with: 'student'
        fill_in 'Email Address', with: 'test@law.harvard.edu'
        fill_in 'Password', with: users(:student_user).crypted_password
        fill_in 'Password confirmation', with: users(:student_user).crypted_password
        check 'Terms of Service' # This works as long as it's in a <label>
        click_button 'Register'

        assert_content 'Account registered! You will be notified once an admin has verified your account.'
      end

      scenario 'fails with an existing username or email' do
        fill_in 'Login', with: users(:case_admin).login
        fill_in 'Email Address', with: users(:case_admin).email_address
        fill_in 'Password', with: users(:student_user).crypted_password
        fill_in 'Password confirmation', with: users(:student_user).crypted_password
        check 'Terms of Service'

        click_button 'Register'

        assert_content 'Email address has already been taken'
      end

      scenario 'fails with an invalid username, email, or password' do
        fill_in 'Login', with: 'student'
        fill_in 'Email Address', with: 'student@gmail.com'
        fill_in 'Password', with: users(:student_user).crypted_password
        fill_in 'Password confirmation', with: users(:student_user).crypted_password
        check 'Terms of Service'
        click_button 'Register'

        assert_content 'Email address must be a .edu address'
      end
    end

    scenario 'browsing users' do
      # do users have public profile pages? what are they used for?
      ## see their playlists
    end
  end

  describe 'as a registered user' do
    describe 'logging in' do

      before do
        visit '/'
      end

      scenario 'succeeds with a valid email and password' do
        user = User.new(login: 'test', email_address: 'email@law.harvard.edu', verified: true)
        user.set_password = (password = 'password') # There's probably a better way to do this
        user.save

        click_link "sign in"

        fill_in 'Login', with: user.login
        fill_in 'Password', with: password

        # click_button 'LOGIN'
        click_button 'Login' # Capitalization changes on the popup...
        # assert_content "#{user.login} Dashboard".upcase # This is rendered by JavaScript?!
        assert_link "sign out"
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
