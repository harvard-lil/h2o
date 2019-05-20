require 'application_system_test_case'

class UserSystemTest < ApplicationSystemTestCase
  describe 'as an anonymous visitor' do
    describe 'signing up for an account' do
      before do
        visit root_path
        click_link 'Sign up for free'
      end

      scenario 'sign up with only an email' do
        fill_in 'Email address', with: 'test@law.harvard.edu'
        click_button 'Sign up'
        assert_content 'Thanks! Please check your email for a link that will let you confirm your account and set a password.'
      end

      scenario 'fails with an existing email' do
        fill_in 'Email address', with: users(:case_admin).email_address
        click_button 'Sign up'
        # NOTE: 'addresshas' is correct
        assert_content 'Email addresshas already been taken'
      end

      scenario 'fails with an invalid email' do
        fill_in 'Email address', with: 'student@gmail.com'
        click_button 'Sign up'
        assert_content 'Email address is not .edu.'
      end
    end
    scenario 'browsing users', solr: true do
      visit users_path
      assert_content "verified_professor"
    end
    scenario 'browsing a non-user' do
      visit user_path(:nonID)
      assert_current_path root_path
    end
    scenario 'browsing a user with content', solr: true, js: true do
      public_casebook = content_nodes(:public_casebook)
      private_casebook = content_nodes(:private_casebook)
      visit user_path public_casebook.owners.first

      assert_content public_casebook.title
      assert_no_content private_casebook.title
    end
  end

  describe 'as a registered user' do
    describe 'logging in' do

      before do
        visit root_path
      end

      scenario 'succeeds with a valid email and password' do
        user = User.new(login: 'test', email_address: 'email@law.harvard.edu')
        user.set_password = (password = 'password') # There's probably a better way to do this
        user.save

        click_link 'Sign in'

        fill_in 'Email address', with: user.login
        fill_in 'Password', with: password

        # click_button 'LOGIN'
        click_button 'Sign in' # Capitalization changes on the popup...
        # assert_content "#{user.login} Dashboard".upcase # This is rendered by JavaScript?!

        assert_button "Sign out"
      end

      scenario 'fails with a non-existent login' do
        click_link 'Sign in'

        fill_in 'Email address', with: 'login'
        fill_in 'Password', with: 'badpassword'

        click_button 'Sign in'

        assert_content 'Email addressis not valid'
      end

      scenario 'fails with an invalid password' do
        user = users(:student_user)

        click_link 'Sign in'

        fill_in 'Email address', with: user.login
        fill_in 'Password', with: 'badpassword'

        click_button 'Sign in'

        assert_content 'Passwordis not valid'
      end

      scenario 'sending a password reset email' do
        user = users(:student_user)

        click_link 'Sign in'
        click_link 'click here to reset it'

        fill_in 'Email address', with: user.login

        perform_enqueued_jobs do
          click_button 'Send reset email'
          assert_sends_emails 1, wait: 10.seconds
        end

        assert_content 'A password reset link has been sent'

        match = ActionMailer::Base.deliveries.last.body.match %r{(/password_resets/.+/edit)}
        assert match.present?
        visit match[1]

        fill_in 'Password', with: 'newestpassword'
        fill_in 'Confirm password', with: 'newestpassword'
        click_button 'Save password'

        assert_content 'Password successfully updated'
      end

      scenario 'browsing owned casebooks' do
        private_casebook = content_nodes(:private_casebook)
        sign_in user = private_casebook.owners.first
        visit user_path(user)

        assert_content private_casebook.title
      end
    end

    describe 'updating account' do
      before do
        user = users(:verified_professor)
        @password = sign_in(user)
        visit user_path user
        find('a.user-link', text: 'Edit profile').click
      end

      scenario 'changing email address'  do
        fill_in 'Email address', with: 'new_mail@law.harvard.edu'
        click_button 'Save changes'
      end

      scenario 'changing password'  do
        fill_in 'Current password', with: @password
        fill_in 'Password', with: 'newestpassword'
        fill_in 'Confirm password', with: 'newestpassword'
        click_button 'Change password'

        assert_content 'Profile updated.'
      end

      scenario 'changing profile information'  do
        fill_in 'Display name', with: 'New name'
        fill_in 'Affiliation', with: 'New affiliation'
        click_button 'Save changes'
      end
    end

    describe 'accessing dashboard' do
      before do
        user = users(:verified_professor)
        @password = sign_in(user)
        visit user_path user
        find('a.user-link', text: 'Dashboard').click
      end

      scenario 'visit dashboard'  do
        assert_content 'Casebooks'
      end

    end
  end
end
