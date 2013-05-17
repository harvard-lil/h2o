FactoryGirl.define do
  factory :user do
    sequence :login do |n|
      "person#{n}"
    end
    password 'password'
    password_confirmation 'password' 
    sequence :email_address do |n|
      "person#{n}@example.com"
    end
  end
end