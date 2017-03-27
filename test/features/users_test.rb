require 'test_helper'

feature 'users' do
  describe 'as an anonymous visitor' do
    describe 'signing up for an account' do
      before do
        visit '/'
        click_link 'sign in'
        click_link 'SIGN UP NOW'
      end

      scenario 'succeeds with a valid username, password, and email' do
        fill_in 'user_login', with: 'student'
        fill_in 'user_email_address', with: 'test@law.harvard.edu'
        fill_in 'user_password', with: users(:student_user).crypted_password
        fill_in 'user_password_confirmation', with: users(:student_user).crypted_password
        find('#user_terms[value="1"]').set(true)
        click_button 'Register'

        assert_content 'Account registered! You will be notified once an admin has verified your account.'

        # skip 'requires verification by an administrator to complete'
      end

      scenario 'fails with an existing username or email' do
        fill_in 'user_login', with: users(:case_admin).login
        fill_in 'user_email_address', with: users(:case_admin).email_address
        fill_in 'user_password', with: users(:student_user).crypted_password
        fill_in 'user_password_confirmation', with: users(:student_user).crypted_password
        find('#user_terms[value="1"]').set(true)

        click_button 'Register'

        assert_content 'Email address has already been taken'
      end

      scenario 'fails with an invalid username, email, or password' do
        fill_in 'user_login', with: 'student'
        fill_in 'user_email_address', with: 'student@gmail.com'
        fill_in 'user_password', with: users(:student_user).crypted_password
        fill_in 'user_password_confirmation', with: users(:student_user).crypted_password

        find('#user_terms[value="1"]').set(true)

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
        skip
        # login/password not getting filled in before clicking login
        user = User.new(login: 'test', email_address: 'email@law.harvard.edu',
          crypted_password: 'secretpassword', verified: true)

        click_link "sign in"

        within('div#login-popup div.right form#new_user_session') do
          fill_in 'user_session_login', with: user.login
          fill_in 'user_session_password', with: user.crypted_password
        end

        click_button 'Login'

        assert_content "#{user.login} Dashboard"
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
