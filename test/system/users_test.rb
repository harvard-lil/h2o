require 'application_system_test_case'

class UserSystemTest < ApplicationSystemTestCase
  describe 'as an anonymous visitor' do
    describe 'signing up for an account' do
      before do
        visit root_path
        click_link 'Sign up for free'
      end

      scenario 'succeeds with a valid username, password, and email' do
        fill_in 'Email address', with: 'test@law.harvard.edu'
        fill_in 'Password', with: users(:student_user).crypted_password
        fill_in 'Confirm password', with: users(:student_user).crypted_password # This works as long as it's in a <label>
        click_button 'Sign up'

        assert_content 'Account registered! Only verified .edu addresses are allowed.'
      end

      scenario 'fails with an existing username or email' do
        fill_in 'Email address', with: users(:case_admin).email_address
        fill_in 'Password', with: users(:student_user).crypted_password
        fill_in 'Confirm password', with: users(:student_user).crypted_password

        click_button 'Sign up'

        assert_content 'Email addresshas already been taken'
      end

      scenario 'fails with an invalid username, email, or password' do
        fill_in 'Email address', with: 'student@gmail.com'
        fill_in 'Password', with: users(:student_user).crypted_password
        fill_in 'Confirm password', with: users(:student_user).crypted_password

        click_button 'Sign up'

        assert_content 'Email address is not .edu.'
      end
    end
    scenario 'browsing users', solr: true do
      visit users_path
      assert_content "student_user"
    end
    scenario 'browsing a non-user' do
      visit user_path(:nonID)
      assert_current_path root_path
    end
    scenario 'browsing a user with content', solr: true, js: true do
      skip 'No user page'
      visit user_path users(:case_admin)

      within '#advanced-search-content' do
        click_link 'Case'
      end
      assert_content 'District Case 1'
      assert_no_content 'Private Case 1'
    end
  end

  describe 'as a registered user' do
    describe 'logging in' do

      before do
        visit root_path
      end

      scenario 'succeeds with a valid email and password' do
        user = User.new(login: 'test', email_address: 'email@law.harvard.edu', verified: true)
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
        assert { match.present? }
        visit match[1]

        fill_in 'Password', with: 'newestpassword'
        fill_in 'Password confirmation', with: 'newestpassword'
        click_button 'Update my password'

        assert_content 'Password successfully updated'
      end

      scenario 'browsing workshop content', js: true, solr: true do
        skip 'user page wip'
        sign_in user = users(:case_admin)
        visit user_path(user)

        assert_content 'My Workshop'
        assert_content cases(:public_case_1).name

        within '#bookshelf_panel .pagination' do
          click_link '6'
        end
        assert_content defaults(:admin_link).name
      end
    end

    describe 'updating account' do
      before do
        skip 'user page WIP'
        user = users(:case_admin)
        sign_in(user)
        visit user_path user
        click_link 'Edit Profile'
      end

      scenario 'changing email address', js: true  do
        fill_in 'Email address', with: 'new_mail@law.harvard.edu'
        click_button 'Submit'
      end

      scenario 'changing password', js: true  do
        fill_in 'Change password', with: 'newestpassword'
        fill_in 'Confirm password', with: 'newestpassword'
        click_button 'Submit'

        assert_content 'Your account has been updated.'
      end

      scenario 'changing profile information', js: true  do
        fill_in 'Name', with: 'New name'
        fill_in 'Title', with: 'New title'
        fill_in 'Affiliation', with: 'New affiliation'
        click_button 'Submit'
      end
    end
  end
  describe 'as an administrator' do
    scenario 'verifying a new user account' do
      # done manually
    end
    scenario 'rejecting a new user account' do
      #done manually
    end
  end
end
